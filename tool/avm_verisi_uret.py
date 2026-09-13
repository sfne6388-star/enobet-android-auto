#!/usr/bin/env python3
import json
import math
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

if len(sys.argv) != 6:
    raise SystemExit(
        "Kullanim: avm_verisi_uret.py <avm_adaylari.geojsonseq> "
        "<magaza_adaylari.geojsonseq> <turkiye_hizmetleri.json> "
        "<avmler.json> <avm_magazalari.json>"
    )

avm_geojson_path = Path(sys.argv[1])
store_geojson_path = Path(sys.argv[2])
services_path = Path(sys.argv[3])
avm_output_path = Path(sys.argv[4])
store_output_path = Path(sys.argv[5])


def normalize(text):
    table = str.maketrans({
        "ı": "i", "İ": "i", "ğ": "g", "Ğ": "g",
        "ü": "u", "Ü": "u", "ş": "s", "Ş": "s",
        "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
    })
    return re.sub(
        r"[^a-z0-9]+",
        " ",
        str(text or "").translate(table).lower(),
    ).strip()


def first_nonempty(*values):
    for value in values:
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return ""


def feature_tags(feature):
    props = feature.get("properties") or {}
    return {
        str(k): v
        for k, v in props.items()
        if not str(k).startswith("@")
    }


def osm_identity(feature):
    props = feature.get("properties") or {}
    osm_type = first_nonempty(
        props.get("@type"),
        props.get("osm_type"),
    )
    osm_id = first_nonempty(
        props.get("@id"),
        props.get("osm_id"),
        props.get("id"),
    )

    if osm_type not in {"node", "way", "relation"} or not osm_id:
        return None

    try:
        return osm_type, int(str(osm_id).split("/")[-1])
    except (TypeError, ValueError):
        return None


def flatten_coords(value, out):
    if isinstance(value, list):
        if (
            len(value) >= 2
            and isinstance(value[0], (int, float))
            and isinstance(value[1], (int, float))
        ):
            out.append((float(value[0]), float(value[1])))
            return
        for item in value:
            flatten_coords(item, out)


def geometry_center(geometry):
    if not isinstance(geometry, dict):
        return None

    coords = []
    flatten_coords(geometry.get("coordinates"), coords)

    if not coords:
        return None

    min_lon = min(x for x, _ in coords)
    max_lon = max(x for x, _ in coords)
    min_lat = min(y for _, y in coords)
    max_lat = max(y for _, y in coords)

    return (
        (min_lat + max_lat) / 2.0,
        (min_lon + max_lon) / 2.0,
    )


def geometry_bbox(geometry):
    if not isinstance(geometry, dict):
        return None

    coords = []
    flatten_coords(geometry.get("coordinates"), coords)

    if not coords:
        return None

    return (
        min(y for _, y in coords),
        min(x for x, _ in coords),
        max(y for _, y in coords),
        max(x for x, _ in coords),
    )


def has_area_geometry(geometry):
    return isinstance(geometry, dict) and geometry.get("type") in {
        "Polygon",
        "MultiPolygon",
    }


def point_in_ring(lon, lat, ring):
    if not isinstance(ring, list) or len(ring) < 3:
        return False

    inside = False
    j = len(ring) - 1

    for i in range(len(ring)):
        a = ring[i]
        b = ring[j]

        if (
            isinstance(a, list)
            and len(a) >= 2
            and isinstance(b, list)
            and len(b) >= 2
        ):
            xi, yi = float(a[0]), float(a[1])
            xj, yj = float(b[0]), float(b[1])

            crosses = ((yi > lat) != (yj > lat))
            if crosses:
                denom = yj - yi
                if abs(denom) > 1e-15:
                    cross_lon = (xj - xi) * (lat - yi) / denom + xi
                    if lon < cross_lon:
                        inside = not inside

        j = i

    return inside


def point_in_polygon(lon, lat, polygon):
    if not isinstance(polygon, list) or not polygon:
        return False

    if not point_in_ring(lon, lat, polygon[0]):
        return False

    for hole in polygon[1:]:
        if point_in_ring(lon, lat, hole):
            return False

    return True


def point_in_geometry(lon, lat, geometry):
    if not isinstance(geometry, dict):
        return False

    gtype = geometry.get("type")
    coords = geometry.get("coordinates")

    if gtype == "Polygon":
        return point_in_polygon(lon, lat, coords)

    if gtype == "MultiPolygon" and isinstance(coords, list):
        return any(point_in_polygon(lon, lat, polygon) for polygon in coords)

    return False


def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0088
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
    )

    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def build_address(tags, il, ilce):
    full = first_nonempty(tags.get("addr:full"))
    if full:
        return full

    parts = []
    for key in (
        "addr:neighbourhood",
        "addr:quarter",
        "addr:suburb",
        "addr:street",
        "addr:housenumber",
    ):
        value = first_nonempty(tags.get(key))
        if value and value not in parts:
            parts.append(value)

    if ilce and ilce not in parts:
        parts.append(ilce)

    if il and il not in parts:
        parts.append(il)

    return ", ".join(parts) if parts else "Adres bilgisi yok"


services = json.loads(services_path.read_text(encoding="utf-8"))
centers = services.get("centers") or []

usable_centers = []
for center in centers:
    try:
        usable_centers.append(
            (
                str(center.get("il", "")).strip(),
                str(center.get("ilce", "")).strip(),
                float(center["lat"]),
                float(center["lon"]),
            )
        )
    except (KeyError, TypeError, ValueError):
        pass

if not usable_centers:
    raise SystemExit(
        "turkiye_hizmetleri.json icinde il/ilce merkezleri bulunamadi."
    )


def nearest_admin(lat, lon):
    best = None
    best_km = float("inf")

    for il, ilce, c_lat, c_lon in usable_centers:
        rough = abs(lat - c_lat) + abs(lon - c_lon)

        if rough > 3.0 and best is not None:
            continue

        km = haversine_km(lat, lon, c_lat, c_lon)

        if km < best_km:
            best_km = km
            best = (il, ilce)

    return best or ("", "")


def outlet_mi(name, tags):
    text = " ".join(
        normalize(v)
        for v in (
            name,
            tags.get("brand"),
            tags.get("operator"),
            tags.get("official_name"),
            tags.get("alt_name"),
        )
        if v
    )

    outlet_tag = normalize(tags.get("outlet"))
    retail_tag = normalize(tags.get("retail"))
    mall_type = normalize(tags.get("mall:type"))
    shop = normalize(tags.get("shop"))

    return (
        "outlet" in text
        or outlet_tag in {"yes", "true", "only", "outlet"}
        or retail_tag == "outlet"
        or mall_type == "outlet"
        or shop == "outlet"
    )


def avm_adayi_mi(name, tags):
    shop = normalize(tags.get("shop"))

    if shop in {"mall", "shopping_centre", "shopping_center"}:
        return True

    # Outlet merkezleri OSM'de her zaman shop=mall olarak tutulmuyor.
    # Adında Outlet geçen retail alanı / retail bina / department store da
    # AVM & Outlet listesine alınır.
    if outlet_mi(name, tags):
        landuse = normalize(tags.get("landuse"))
        building = normalize(tags.get("building"))

        return (
            landuse == "retail"
            or building in {"retail", "commercial", "yes"}
            or shop in {
                "department_store",
                "mall",
                "shopping_centre",
                "shopping_center",
                "outlet",
            }
        )

    return False


def read_geojsonseq(path):
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.lstrip("\x1e").strip()
            if not line:
                continue
            yield json.loads(line)


raw_malls = []

for feature in read_geojsonseq(avm_geojson_path):
    tags = feature_tags(feature)

    name = first_nonempty(
        tags.get("name"),
        tags.get("official_name"),
        tags.get("brand"),
        tags.get("operator"),
    )

    if not name or not avm_adayi_mi(name, tags):
        continue

    center = geometry_center(feature.get("geometry"))
    identity = osm_identity(feature)

    if center is None or identity is None:
        continue

    lat, lon = center

    if not (35 <= lat <= 43 and 25 <= lon <= 46):
        continue

    osm_type, osm_id = identity
    il, ilce = nearest_admin(lat, lon)

    tag_il = first_nonempty(
        tags.get("addr:province"),
        tags.get("addr:state"),
    )
    tag_ilce = first_nonempty(
        tags.get("addr:district"),
        tags.get("addr:town"),
        tags.get("addr:suburb"),
    )

    if tag_il:
        il = tag_il
    if tag_ilce:
        ilce = tag_ilce

    geometry = feature.get("geometry") or {}
    is_outlet = outlet_mi(name, tags)

    raw_malls.append({
        "id": f"osm_avm_{osm_type}_{osm_id}",
        "osm_type": osm_type,
        "osm_id": osm_id,
        "isim": name,
        "durum": "Outlet" if is_outlet else "AVM",
        "adres": build_address(tags, il, ilce),
        "telefon": first_nonempty(
            tags.get("phone"),
            tags.get("contact:phone"),
            tags.get("contact:mobile"),
            tags.get("mobile"),
        ) or "Telefon bilgisi yok",
        "calismaSaatleri": first_nonempty(
            tags.get("opening_hours"),
        ) or "Çalışma saati belirtilmemiş",
        "enlem": round(lat, 7),
        "boylam": round(lon, 7),
        "il": il,
        "ilce": ilce,
        "_geometry": geometry,
        "_bbox": geometry_bbox(geometry),
        "_area": has_area_geometry(geometry),
    })


def better_mall(a, b):
    # Aynı AVM birden fazla OSM objesiyle kayıtlıysa alan geometrisini seç.
    if b["_area"] and not a["_area"]:
        return b

    # Outlet sınıfı kaybolmasın.
    if b["durum"] == "Outlet" and a["durum"] != "Outlet":
        return b

    return a


deduped_malls = []

for mall in sorted(raw_malls, key=lambda x: normalize(x["isim"])):
    replaced = False

    for index, existing in enumerate(deduped_malls):
        if normalize(existing["isim"]) != normalize(mall["isim"]):
            continue

        if haversine_km(
            existing["enlem"],
            existing["boylam"],
            mall["enlem"],
            mall["boylam"],
        ) < 0.8:
            deduped_malls[index] = better_mall(existing, mall)
            replaced = True
            break

    if not replaced:
        deduped_malls.append(mall)

if not deduped_malls:
    raise SystemExit("AVM / Outlet verisi uretildi fakat kayit bulunamadi.")


def store_type(shop, amenity, leisure):
    if shop:
        names = {
            "clothes": "Giyim",
            "shoes": "Ayakkabı",
            "fashion_accessories": "Aksesuar",
            "jewelry": "Takı",
            "electronics": "Elektronik",
            "mobile_phone": "Telefon",
            "computer": "Bilgisayar",
            "cosmetics": "Kozmetik",
            "beauty": "Güzellik",
            "perfumery": "Parfümeri",
            "supermarket": "Süpermarket",
            "convenience": "Market",
            "department_store": "Mağaza",
            "sports": "Spor",
            "books": "Kitap",
            "toys": "Oyuncak",
            "optician": "Optik",
            "gift": "Hediye",
            "bag": "Çanta",
            "leather": "Deri",
            "furniture": "Mobilya",
            "houseware": "Ev Ürünleri",
            "interior_decoration": "Ev Dekorasyon",
            "hairdresser": "Kuaför",
            "chemist": "Kişisel Bakım",
            "variety_store": "Çeşitli Ürünler",
        }
        return names.get(shop, shop.replace("_", " ").title())

    amenity_names = {
        "restaurant": "Restoran",
        "cafe": "Kafe",
        "fast_food": "Hızlı Yemek",
        "food_court": "Yemek Alanı",
        "cinema": "Sinema",
        "pharmacy": "Eczane",
    }

    if amenity:
        return amenity_names.get(
            amenity,
            amenity.replace("_", " ").title(),
        )

    if leisure == "fitness_centre":
        return "Fitness"

    return "Mağaza"


def store_category(shop, amenity, leisure):
    if shop in {
        "clothes",
        "fashion_accessories",
        "bag",
        "leather",
        "jewelry",
    }:
        return "Giyim"

    if shop == "shoes":
        return "Ayakkabı"

    if shop in {
        "electronics",
        "mobile_phone",
        "computer",
        "video_games",
    }:
        return "Teknoloji"

    if shop in {
        "cosmetics",
        "beauty",
        "perfumery",
        "chemist",
        "hairdresser",
    }:
        return "Kozmetik"

    if shop in {
        "supermarket",
        "convenience",
        "department_store",
        "variety_store",
    }:
        return "Market"

    if amenity in {
        "restaurant",
        "cafe",
        "fast_food",
        "food_court",
    }:
        return "Yeme İçme"

    if amenity == "cinema" or leisure == "fitness_centre":
        return "Eğlence"

    if amenity == "pharmacy" or shop in {
        "optician",
        "medical_supply",
    }:
        return "Sağlık"

    return "Diğer"


def floor_text(tags):
    raw = first_nonempty(
        tags.get("level:ref"),
        tags.get("level"),
    )

    if not raw:
        return ""

    values = [
        v.strip()
        for v in re.split(r"[;,]", raw)
        if v.strip()
    ]

    result = []

    for value in values:
        normalized = normalize(value)

        if normalized in {"0", "ground", "zemin", "g"}:
            text = "Zemin Kat"
        elif re.fullmatch(r"-?\d+", value):
            number = int(value)
            if number == 0:
                text = "Zemin Kat"
            else:
                text = f"{number}. Kat"
        else:
            text = value

        if text not in result:
            result.append(text)

    return " / ".join(result)


# 0.05 derece yaklaşık 4-5 km. AVM adaylarını küçük hücrelere indeksleyerek
# yüz binlerce mağaza kaydını hızlıca eşleştiriyoruz.
CELL = 0.05
EXPAND = 0.006  # yaklaşık 500-650 m


def cell_key(lat, lon):
    return (
        math.floor(lat / CELL),
        math.floor(lon / CELL),
    )


grid = defaultdict(list)

for index, mall in enumerate(deduped_malls):
    bbox = mall["_bbox"]

    if bbox is None:
        min_lat = max_lat = mall["enlem"]
        min_lon = max_lon = mall["boylam"]
    else:
        min_lat, min_lon, max_lat, max_lon = bbox

    min_lat -= EXPAND
    min_lon -= EXPAND
    max_lat += EXPAND
    max_lon += EXPAND

    row_min = math.floor(min_lat / CELL)
    row_max = math.floor(max_lat / CELL)
    col_min = math.floor(min_lon / CELL)
    col_max = math.floor(max_lon / CELL)

    for row in range(row_min, row_max + 1):
        for col in range(col_min, col_max + 1):
            grid[(row, col)].append(index)


mall_stores = {
    mall["id"]: {}
    for mall in deduped_malls
}
fallback_counts = defaultdict(int)
inside_counts = defaultdict(int)

allowed_amenities = {
    "restaurant",
    "cafe",
    "fast_food",
    "food_court",
    "cinema",
    "pharmacy",
}

for feature in read_geojsonseq(store_geojson_path):
    tags = feature_tags(feature)

    shop = normalize(tags.get("shop"))
    amenity = normalize(tags.get("amenity"))
    leisure = normalize(tags.get("leisure"))

    if not (
        shop
        or amenity in allowed_amenities
        or leisure == "fitness_centre"
    ):
        continue

    # AVM objesinin kendisini mağaza olarak listeleme.
    if shop in {"mall", "shopping_centre", "shopping_center"}:
        continue

    name = first_nonempty(
        tags.get("name"),
        tags.get("brand"),
        tags.get("official_name"),
        tags.get("operator"),
    )

    if not name:
        continue

    center = geometry_center(feature.get("geometry"))
    identity = osm_identity(feature)

    if center is None or identity is None:
        continue

    lat, lon = center

    if not (35 <= lat <= 43 and 25 <= lon <= 46):
        continue

    candidate_indexes = grid.get(cell_key(lat, lon), [])

    if not candidate_indexes:
        continue

    store_osm_type, store_osm_id = identity

    inside = []
    nearby = []

    indoor_signal = any(
        first_nonempty(tags.get(key))
        for key in ("indoor", "level", "level:ref", "addr:unit")
    )

    for mall_index in candidate_indexes:
        mall = deduped_malls[mall_index]

        if (
            mall["osm_type"] == store_osm_type
            and mall["osm_id"] == store_osm_id
        ):
            continue

        if normalize(name) == normalize(mall["isim"]):
            continue

        if mall["_area"] and point_in_geometry(
            lon,
            lat,
            mall["_geometry"],
        ):
            distance = haversine_km(
                lat,
                lon,
                mall["enlem"],
                mall["boylam"],
            )
            inside.append((distance, mall_index))
            continue

        distance = haversine_km(
            lat,
            lon,
            mall["enlem"],
            mall["boylam"],
        )

        if mall["durum"] == "Outlet":
            limit = 0.50
        elif indoor_signal:
            limit = 0.40
        else:
            limit = 0.24 if mall["_area"] else 0.32

        if distance <= limit:
            nearby.append((distance, mall_index))

    mode = None
    chosen = None

    if inside:
        inside.sort(key=lambda x: x[0])
        _, chosen = inside[0]
        mode = "inside"
    elif nearby:
        nearby.sort(key=lambda x: x[0])
        _, chosen = nearby[0]
        mode = "nearby"

    if chosen is None:
        continue

    mall = deduped_malls[chosen]
    floor = floor_text(tags)

    record = {
        "id": f"{store_osm_type}_{store_osm_id}",
        "isim": name,
        "tur": store_type(shop, amenity, leisure),
        "kategori": store_category(shop, amenity, leisure),
        "kat": floor,
        "telefon": first_nonempty(
            tags.get("phone"),
            tags.get("contact:phone"),
            tags.get("contact:mobile"),
            tags.get("mobile"),
        ),
        "website": first_nonempty(
            tags.get("website"),
            tags.get("contact:website"),
        ),
    }

    key = f"{normalize(name)}|{normalize(floor)}"
    mall_stores[mall["id"]].setdefault(key, record)

    if mode == "inside":
        inside_counts[mall["id"]] += 1
    else:
        fallback_counts[mall["id"]] += 1


public_malls = []

for mall in deduped_malls:
    public_malls.append({
        key: value
        for key, value in mall.items()
        if not key.startswith("_")
        and key not in {"osm_type", "osm_id"}
    })

public_malls.sort(
    key=lambda x: (
        normalize(x["il"]),
        normalize(x["ilce"]),
        normalize(x["isim"]),
    )
)

mall_directory = {}
store_total = 0
malls_with_stores = 0

for mall in public_malls:
    records = list(mall_stores[mall["id"]].values())
    records.sort(
        key=lambda x: (
            normalize(x["isim"]),
            normalize(x["kat"]),
        )
    )

    store_total += len(records)

    if records:
        malls_with_stores += 1

    mall_directory[mall["id"]] = {
        "avmAdi": mall["isim"],
        "sinirIci": (
            inside_counts[mall["id"]] > 0
            and fallback_counts[mall["id"]] == 0
        ),
        "records": records,
    }


generated_at = datetime.now(timezone.utc).isoformat()
outlet_count = sum(1 for item in public_malls if item["durum"] == "Outlet")

avm_output = {
    "version": 2,
    "source": "OpenStreetMap / Geofabrik Turkey extract",
    "sourceUrl": "https://download.geofabrik.de/europe/turkey.html",
    "license": "Open Database License (ODbL) 1.0",
    "attribution": "© OpenStreetMap contributors",
    "generatedAt": generated_at,
    "recordCount": len(public_malls),
    "outletCount": outlet_count,
    "records": public_malls,
}

store_output = {
    "version": 1,
    "source": "OpenStreetMap / Geofabrik Turkey extract",
    "sourceUrl": "https://download.geofabrik.de/europe/turkey.html",
    "license": "Open Database License (ODbL) 1.0",
    "attribution": "© OpenStreetMap contributors",
    "generatedAt": generated_at,
    "avmCount": len(public_malls),
    "avmWithStores": malls_with_stores,
    "storeCount": store_total,
    "malls": mall_directory,
}

avm_output_path.parent.mkdir(parents=True, exist_ok=True)
store_output_path.parent.mkdir(parents=True, exist_ok=True)

avm_output_path.write_text(
    json.dumps(
        avm_output,
        ensure_ascii=False,
        separators=(",", ":"),
    ),
    encoding="utf-8",
)

store_output_path.write_text(
    json.dumps(
        store_output,
        ensure_ascii=False,
        separators=(",", ":"),
    ),
    encoding="utf-8",
)

print(f"Toplam AVM / Outlet: {len(public_malls)}")
print(f"Outlet: {outlet_count}")
print(f"Magaza verisi olan AVM / Outlet: {malls_with_stores}")
print(f"Toplam AVM ici magaza: {store_total}")
