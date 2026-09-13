#!/usr/bin/env python3
import json
import math
import re
import unicodedata
from datetime import date
from pathlib import Path

BASE = Path("assets/data/turkiye_hizmetleri.json")
CANDIDATES = Path("/tmp/oto_ekspertiz_adaylari.geojson")
CATEGORY = "Oto Ekspertiz"

# Türkiye'de oto ekspertiz işletmelerinde sık görülen ifadeler/markalar.
POSITIVE_TERMS = (
    "ekspertiz",
    "eksper",
    "expertiz",
    "expertise",
    "auto expert",
    "oto expert",
    "otoexpert",
    "otorapor",
    "oto rapor",
    "oto test",
    "oto kontrol",
    "arac kontrol",
    "araç kontrol",
    "computest",
    "dynobil",
    "d expert",
    "dexpert",
    "pilot garage",
    "check up",
    "checkup",
    "auto check",
    "autocheck",
    "car check",
    "carcheck",
    "oto analiz",
    "arac analiz",
    "araç analiz",
    "oto ekspert",
    "auto expertise",
    "car expertise",
    "expert auto",
)

# Resmî periyodik araç muayene istasyonlarını ekspertiz diye göstermeyelim.
BLOCKED_TERMS = (
    "tuvturk",
    "tuv turk",
    "tüvtürk",
    "arac muayene",
    "araç muayene",
    "tasit muayene",
    "taşıt muayene",
    "vehicle inspection station",
    "inspection station",
)


def norm(value):
    if value is None:
        return ""
    s = str(value).strip().lower()
    s = s.translate(
        str.maketrans(
            {
                "ç": "c",
                "ğ": "g",
                "ı": "i",
                "ö": "o",
                "ş": "s",
                "ü": "u",
                "Ç": "c",
                "Ğ": "g",
                "İ": "i",
                "I": "i",
                "Ö": "o",
                "Ş": "s",
                "Ü": "u",
            }
        )
    )
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return " ".join(s.split())


POSITIVE_NORM = tuple(norm(x) for x in POSITIVE_TERMS)
BLOCKED_NORM = tuple(norm(x) for x in BLOCKED_TERMS)


def truthy_tag(tags, key):
    value = norm(tags.get(key))
    return value in {"yes", "true", "1"}


def points_from_geometry(g):
    if not g:
        return []
    t = g.get("type")
    c = g.get("coordinates")
    if t == "Point":
        return [c] if isinstance(c, list) and len(c) >= 2 else []

    pts = []

    def walk(v):
        if isinstance(v, list):
            if (
                len(v) >= 2
                and isinstance(v[0], (int, float))
                and isinstance(v[1], (int, float))
            ):
                pts.append(v)
            else:
                for x in v:
                    walk(x)

    walk(c)
    return pts


def representative_point(g):
    pts = points_from_geometry(g)
    if not pts:
        return None
    lon = sum(float(p[0]) for p in pts) / len(pts)
    lat = sum(float(p[1]) for p in pts) / len(pts)
    if not (-180 <= lon <= 180 and -90 <= lat <= 90):
        return None
    return lat, lon


def osm_identity(feature):
    props = feature.get("properties") or {}
    raw = feature.get("id") or props.get("@id") or props.get("id") or ""
    raw = str(raw)

    if "/" in raw:
        typ, ident = raw.split("/", 1)
        if typ in {"node", "way", "relation"}:
            try:
                return typ, int(ident)
            except Exception:
                pass

    osm_type = props.get("@type") or props.get("osm_type") or "node"
    osm_id = props.get("@id") or props.get("osm_id") or props.get("id")
    try:
        osm_id = int(str(osm_id).split("/")[-1])
    except Exception:
        return None

    if osm_type not in {"node", "way", "relation"}:
        osm_type = "node"
    return osm_type, osm_id


def all_tags(feature):
    props = dict(feature.get("properties") or {})
    nested = props.get("tags")
    if isinstance(nested, dict):
        return dict(nested)

    return {
        k: v
        for k, v in props.items()
        if not str(k).startswith("@")
        and k not in {"id", "osm_id", "osm_type", "type"}
    }


def clean_tags(tags):
    wanted = {
        "name",
        "official_name",
        "brand",
        "operator",
        "description",
        "phone",
        "contact:phone",
        "mobile",
        "contact:mobile",
        "website",
        "contact:website",
        "opening_hours",
        "addr:street",
        "addr:housenumber",
        "addr:neighbourhood",
        "addr:suburb",
        "addr:district",
        "addr:city",
        "addr:province",
        "addr:state",
        "addr:postcode",
        "amenity",
        "shop",
        "service:vehicle:inspection",
        "service:vehicle:repair",
        "service:vehicle",
    }
    return {
        k: tags[k]
        for k in wanted
        if tags.get(k) is not None and str(tags.get(k)).strip()
    }


def is_oto_ekspertiz(tags):
    name_blob = " ".join(
        norm(tags.get(k))
        for k in ("name", "official_name", "brand", "operator", "description")
        if tags.get(k)
    ).strip()

    if any(term in name_blob for term in BLOCKED_NORM):
        return False

    if any(term in name_blob for term in POSITIVE_NORM):
        return True

    # service:vehicle:inspection=yes tek basina ekspertiz kaniti degildir.
    # Bu etiket normal bakim/tamir servislerinde de kullanilabildigi icin
    # yalnizca yukaridaki ekspertiz/eksper/Computest/Pilot Garage vb.
    # guclu isim, marka, operator veya aciklama eslesmeleri kabul edilir.
    return False


def squared_distance(lat1, lon1, lat2, lon2):
    scale = math.cos(math.radians((lat1 + lat2) / 2.0))
    return (lat1 - lat2) ** 2 + ((lon1 - lon2) * scale) ** 2


def main():
    if not BASE.exists():
        raise SystemExit(f"Bulunamadı: {BASE}")
    if not CANDIDATES.exists():
        raise SystemExit(f"Bulunamadı: {CANDIDATES}")

    data = json.loads(BASE.read_text(encoding="utf-8"))
    records = data.get("records", [])
    centers = data.get("centers", [])

    if not isinstance(records, list) or not isinstance(centers, list):
        raise SystemExit("Ana veri dosyası beklenen yapıda değil.")

    province_names = {}
    district_names = {}
    centers_by_province = {}
    usable_centers = []

    for c in centers:
        try:
            il = str(c["il"]).strip()
            ilce = str(c["ilce"]).strip()
            lat = float(c["lat"])
            lon = float(c["lon"])
        except Exception:
            continue

        province_names[norm(il)] = il
        district_names[(norm(il), norm(ilce))] = ilce
        centers_by_province.setdefault(norm(il), []).append((lat, lon, il, ilce))
        usable_centers.append((lat, lon, il, ilce))

    # Önceki üretimi temizle, diğer kategorileri koru.
    cleaned = []
    existing_by_osm = {}
    removed_old_only = 0

    for r in records:
        cats = list(r.get("categories") or [])
        if CATEGORY in cats:
            cats = [x for x in cats if x != CATEGORY]
            if not cats:
                removed_old_only += 1
                continue
            r["categories"] = cats

        cleaned.append(r)
        try:
            existing_by_osm[(str(r.get("type")), int(r.get("id")))] = r
        except Exception:
            pass

    records = cleaned
    geo = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    features = geo.get("features", [])

    added = 0
    merged = 0
    filtered_out = 0
    skipped = 0

    for f in features:
        ident = osm_identity(f)
        pt = representative_point(f.get("geometry"))
        if ident is None or pt is None:
            skipped += 1
            continue

        raw_tags = all_tags(f)
        if not is_oto_ekspertiz(raw_tags):
            filtered_out += 1
            continue

        osm_type, osm_id = ident
        lat, lon = pt
        tags = clean_tags(raw_tags)
        key = (osm_type, osm_id)

        if key in existing_by_osm:
            r = existing_by_osm[key]
            cats = list(r.get("categories") or [])
            if CATEGORY not in cats:
                cats.append(CATEGORY)
                r["categories"] = cats

            rt = dict(r.get("tags") or {})
            for k, v in tags.items():
                if k not in rt or not str(rt.get(k, "")).strip():
                    rt[k] = v
            r["tags"] = rt
            merged += 1
            continue

        raw_il = tags.get("addr:province") or tags.get("addr:state")
        il = province_names.get(norm(raw_il), "")
        ilce = ""

        if il:
            for candidate in (tags.get("addr:district"), tags.get("addr:city")):
                exact = district_names.get((norm(il), norm(candidate)))
                if exact:
                    ilce = exact
                    break

        candidates = (
            centers_by_province.get(norm(il), usable_centers)
            if il
            else usable_centers
        )
        nearest = None
        nearest_d = float("inf")
        for clat, clon, cil, cilce in candidates:
            d = squared_distance(lat, lon, clat, clon)
            if d < nearest_d:
                nearest_d = d
                nearest = (cil, cilce)

        if nearest:
            if not il:
                il = nearest[0]
            if not ilce:
                ilce = nearest[1]

        if not il or not ilce:
            skipped += 1
            continue

        record = {
            "type": osm_type,
            "id": osm_id,
            "lat": round(lat, 7),
            "lon": round(lon, 7),
            "tags": tags,
            "categories": [CATEGORY],
            "il": il,
            "ilce": ilce,
        }
        records.append(record)
        existing_by_osm[key] = record
        added += 1

    data["records"] = records
    data["otoEkspertizSource"] = "OpenStreetMap contributors / Geofabrik Turkey extract"
    data["otoEkspertizSourceUrl"] = "https://download.geofabrik.de/europe/turkey.html"
    data["otoEkspertizSnapshot"] = date.today().isoformat()
    data["otoEkspertizFilter"] = (
        "Ad/marka/operator/açıklama alanında ekspertiz, eksper, oto kontrol, "
        "check-up veya bilinen ekspertiz ağı ifadesi bulunan kayıtlar; "
        "resmî araç muayene istasyonları filtrelenir."
    )
    data["otoEkspertizAdminAssignment"] = (
        "OSM adres etiketleri kullanıldı; eksik il/ilçe alanlarında en yakın "
        "mevcut ilçe merkezi atandı."
    )

    BASE.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    total = sum(1 for r in records if CATEGORY in (r.get("categories") or []))
    provinces = sorted(
        {r.get("il", "") for r in records if CATEGORY in (r.get("categories") or []) and r.get("il")}
    )

    print(
        f"Oto Ekspertiz verisi tamamlandı. Yeni: {added}, "
        f"mevcut kayda eklendi: {merged}, filtre dışı: {filtered_out}, "
        f"atlanan: {skipped}"
    )
    print(f"Eski sadece-Oto Ekspertiz kayıt temizliği: {removed_old_only}")
    print(f"Toplam Oto Ekspertiz kaydı: {total}")
    print(f"Kayıt bulunan il sayısı: {len(provinces)}")
    print(f"Toplam genel kayıt: {len(records)}")

    if total == 0:
        raise SystemExit("HATA: Oto Ekspertiz kaydı oluşmadı.")


if __name__ == "__main__":
    main()
