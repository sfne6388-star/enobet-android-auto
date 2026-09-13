#!/usr/bin/env python3
import json
import math
import re
import hashlib
from datetime import date
from pathlib import Path

BASE = Path("assets/data/turkiye_hizmetleri.json")
NOTARIES = Path("/tmp/notaries.geojson")


def norm(value):
    if value is None:
        return ""
    s = str(value).strip().lower()
    s = s.translate(str.maketrans({
        "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
        "Ç": "c", "Ğ": "g", "İ": "i", "I": "i", "Ö": "o", "Ş": "s", "Ü": "u",
    }))
    return " ".join(s.split())


def points_from_geometry(geometry):
    if not geometry:
        return []
    coordinates = geometry.get("coordinates")
    points = []

    def walk(value):
        if not isinstance(value, list):
            return
        if (
            len(value) >= 2
            and isinstance(value[0], (int, float))
            and isinstance(value[1], (int, float))
        ):
            points.append(value)
            return
        for child in value:
            walk(child)

    walk(coordinates)
    return points


def representative_point(geometry):
    points = points_from_geometry(geometry)
    if not points:
        return None
    lon = sum(float(p[0]) for p in points) / len(points)
    lat = sum(float(p[1]) for p in points) / len(points)
    if not (-180 <= lon <= 180 and -90 <= lat <= 90):
        return None
    return lat, lon


def osm_identity(feature, lat=None, lon=None, tags=None):
    props = feature.get("properties") or {}

    raw_candidates = [
        feature.get("id"),
        props.get("@id"),
        props.get("id"),
        props.get("osm_id"),
    ]

    type_map = {
        "n": "node",
        "w": "way",
        "r": "relation",
        "node": "node",
        "way": "way",
        "relation": "relation",
    }

    for raw_value in raw_candidates:
        if raw_value is None:
            continue

        raw = str(raw_value).strip()
        if not raw:
            continue

        # n123 / w456 / r789
        m = re.fullmatch(r"([nwr])(\d+)", raw, re.IGNORECASE)
        if m:
            return type_map[m.group(1).lower()], int(m.group(2))

        # node/123, way/456, relation/789
        m = re.fullmatch(r"(node|way|relation)/(\d+)", raw, re.IGNORECASE)
        if m:
            return type_map[m.group(1).lower()], int(m.group(2))

        # node123 / way456 / relation789
        m = re.fullmatch(r"(node|way|relation)(\d+)", raw, re.IGNORECASE)
        if m:
            return type_map[m.group(1).lower()], int(m.group(2))

        # Sadece sayısal kimlik
        if raw.isdigit():
            raw_type = str(
                props.get("@type") or props.get("osm_type") or "node"
            ).strip().lower()
            return type_map.get(raw_type, "node"), int(raw)

    # Osmium bazı GeoJSON çıktılarında OSM id'sini taşımayabiliyor.
    # Bu durumda koordinat + isimden kararlı, pozitif bir id üret.
    if lat is not None and lon is not None:
        tags = tags or {}
        fingerprint = "|".join([
            str(tags.get("name") or tags.get("operator") or ""),
            f"{float(lat):.7f}",
            f"{float(lon):.7f}",
        ])
        digest = hashlib.sha1(fingerprint.encode("utf-8")).hexdigest()[:15]
        return "node", int(digest, 16)

    return None


def all_tags(feature):
    props = dict(feature.get("properties") or {})
    nested = props.get("tags")
    if isinstance(nested, dict):
        return dict(nested)

    result = {}
    for key, value in props.items():
        if not str(key).startswith("@") and key not in {"id", "osm_id", "osm_type"}:
            result[str(key)] = value
    return result


def is_notary(tags):
    name = norm(tags.get("name") or tags.get("operator") or "")
    return (
        str(tags.get("office", "")).lower() == "notary"
        or (
            str(tags.get("office", "")).lower() == "lawyer"
            and str(tags.get("lawyer", "")).lower() == "notary"
        )
        or bool(re.search(r"\bnoter(?:lik|ligi|liği)?\b", name))
    )


def clean_tags(feature):
    tags = all_tags(feature)
    wanted = {
        "name", "brand", "operator", "phone", "contact:phone", "mobile",
        "contact:mobile", "website", "contact:website", "opening_hours",
        "addr:street", "addr:housenumber", "addr:neighbourhood", "addr:suburb",
        "addr:district", "addr:city", "addr:province", "addr:state",
        "addr:postcode", "office", "lawyer",
    }
    keep = {}
    for key in wanted:
        value = tags.get(key)
        if value is not None and str(value).strip():
            keep[key] = value

    # ENöbet içinde kategori eşleşmesi için standardize et.
    keep["office"] = "notary"
    return keep


def squared_distance(lat1, lon1, lat2, lon2):
    scale = math.cos(math.radians((lat1 + lat2) / 2.0))
    return (lat1 - lat2) ** 2 + ((lon1 - lon2) * scale) ** 2


def main():
    if not BASE.exists():
        raise SystemExit(f"Bulunamadı: {BASE}")
    if not NOTARIES.exists():
        raise SystemExit(f"Bulunamadı: {NOTARIES}")

    data = json.loads(BASE.read_text(encoding="utf-8"))
    records = data.get("records", [])
    centers = data.get("centers", [])

    if not isinstance(records, list) or not isinstance(centers, list):
        raise SystemExit("Ana veri dosyası beklenen yapıda değil.")

    province_names = {}
    district_names = {}
    centers_by_province = {}
    usable_centers = []

    for center in centers:
        try:
            il = str(center["il"]).strip()
            ilce = str(center["ilce"]).strip()
            lat = float(center["lat"])
            lon = float(center["lon"])
        except Exception:
            continue

        province_names[norm(il)] = il
        district_names[(norm(il), norm(ilce))] = ilce
        centers_by_province.setdefault(norm(il), []).append((lat, lon, il, ilce))
        usable_centers.append((lat, lon, il, ilce))

    # Eski Noter kategorisini temizle; aynı OSM kaydının diğer kategorileri korunur.
    cleaned = []
    existing_by_osm = {}
    removed_notary_only = 0

    for row in records:
        categories = list(row.get("categories") or [])
        if "Noter" in categories:
            categories = [x for x in categories if x != "Noter"]
            if not categories:
                removed_notary_only += 1
                continue
            row["categories"] = categories

        cleaned.append(row)
        try:
            existing_by_osm[(str(row.get("type")), int(row.get("id")))] = row
        except Exception:
            pass

    records = cleaned

    geo = json.loads(NOTARIES.read_text(encoding="utf-8"))
    features = geo.get("features", [])

    added = 0
    merged = 0
    skipped = 0
    skipped_no_geometry = 0
    skipped_no_identity = 0
    skipped_no_region = 0

    for feature in features:
        raw_tags = all_tags(feature)
        if not is_notary(raw_tags):
            continue

        point = representative_point(feature.get("geometry"))
        if point is None:
            skipped += 1
            skipped_no_geometry += 1
            continue

        lat, lon = point
        tags = clean_tags(feature)
        ident = osm_identity(feature, lat=lat, lon=lon, tags=tags)
        if ident is None:
            skipped += 1
            skipped_no_identity += 1
            continue

        osm_type, osm_id = ident
        key = (osm_type, osm_id)

        if key in existing_by_osm:
            row = existing_by_osm[key]
            categories = list(row.get("categories") or [])
            if "Noter" not in categories:
                categories.append("Noter")
                row["categories"] = categories

            old_tags = dict(row.get("tags") or {})
            for tag_key, value in tags.items():
                if tag_key not in old_tags or not str(old_tags.get(tag_key, "")).strip():
                    old_tags[tag_key] = value
            row["tags"] = old_tags
            merged += 1
            continue

        raw_il = tags.get("addr:province") or tags.get("addr:state")
        il = province_names.get(norm(raw_il), "")

        raw_district = tags.get("addr:district")
        raw_city = tags.get("addr:city")
        ilce = ""

        if il:
            for candidate in (raw_district, raw_city):
                exact = district_names.get((norm(il), norm(candidate)))
                if exact:
                    ilce = exact
                    break

        # Eksik il/ilçe için mevcut Türkiye ilçe merkezlerinden en yakını.
        candidates = centers_by_province.get(norm(il), usable_centers) if il else usable_centers
        nearest = None
        nearest_distance = float("inf")

        for clat, clon, cil, cilce in candidates:
            distance = squared_distance(lat, lon, clat, clon)
            if distance < nearest_distance:
                nearest_distance = distance
                nearest = (cil, cilce)

        if nearest:
            if not il:
                il = nearest[0]
            if not ilce:
                ilce = nearest[1]

        if not il or not ilce:
            skipped += 1
            skipped_no_region += 1
            continue

        row = {
            "type": osm_type,
            "id": osm_id,
            "lat": round(lat, 7),
            "lon": round(lon, 7),
            "tags": tags,
            "categories": ["Noter"],
            "il": il,
            "ilce": ilce,
        }
        records.append(row)
        existing_by_osm[key] = row
        added += 1

    data["records"] = records
    data["notarySource"] = "OpenStreetMap contributors / Geofabrik Turkey extract"
    data["notarySourceUrl"] = "https://download.geofabrik.de/europe/turkey.html"
    data["notarySnapshot"] = date.today().isoformat()
    data["notaryTags"] = [
        "office=notary",
        "office=lawyer + lawyer=notary",
        "name contains noter",
    ]
    BASE.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    total_notaries = sum(
        1 for row in records if "Noter" in (row.get("categories") or [])
    )

    print(
        f"Noter verisi tamamlandı. Yeni: {added}, mevcut kayda eklendi: {merged}, "
        f"atlanan: {skipped}"
    )
    print(
        "Atlama nedenleri -> "
        f"geometri yok: {skipped_no_geometry}, "
        f"kimlik yok: {skipped_no_identity}, "
        f"il/ilce yok: {skipped_no_region}"
    )
    print(f"Eski sadece-noter kayıt temizliği: {removed_notary_only}")
    print(f"Toplam Noter kategorisi kaydı: {total_notaries}")
    print(f"Toplam tüm hizmet kaydı: {len(records)}")


if __name__ == "__main__":
    main()
