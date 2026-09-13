#!/usr/bin/env python3
import json
import math
import sys
from datetime import date
from pathlib import Path

BASE = Path("assets/data/turkiye_hizmetleri.json")
HOTELS = Path("/tmp/hotels.geojson")

def norm(s):
    if s is None:
        return ""
    s = str(s).strip().lower()
    tr = str.maketrans({
        "ç":"c","ğ":"g","ı":"i","i":"i","ö":"o","ş":"s","ü":"u",
        "Ç":"c","Ğ":"g","İ":"i","I":"i","Ö":"o","Ş":"s","Ü":"u",
    })
    s = s.translate(tr)
    return " ".join(s.split())

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
            if len(v) >= 2 and isinstance(v[0], (int, float)) and isinstance(v[1], (int, float)):
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

def clean_tags(feature):
    props = dict(feature.get("properties") or {})
    nested = props.get("tags")
    if isinstance(nested, dict):
        tags = dict(nested)
    else:
        tags = {}
        for k, v in props.items():
            if not str(k).startswith("@") and k not in {"id", "osm_id", "osm_type"}:
                tags[k] = v

    keep = {}
    wanted = {
        "name","brand","operator","phone","contact:phone","mobile","contact:mobile",
        "website","contact:website","opening_hours","stars",
        "addr:street","addr:housenumber","addr:neighbourhood","addr:suburb",
        "addr:district","addr:city","addr:province","addr:state","addr:postcode",
        "tourism"
    }
    for k in wanted:
        v = tags.get(k)
        if v is not None and str(v).strip():
            keep[k] = v
    keep["tourism"] = "hotel"
    return keep

def squared_distance(lat1, lon1, lat2, lon2):
    # İlçe ataması için yaklaşık yakınlık yeterli; kosinüs ile boylamı ölçekle.
    scale = math.cos(math.radians((lat1 + lat2) / 2.0))
    return (lat1 - lat2) ** 2 + ((lon1 - lon2) * scale) ** 2

def main():
    if not BASE.exists():
        raise SystemExit(f"Bulunamadı: {BASE}")
    if not HOTELS.exists():
        raise SystemExit(f"Bulunamadı: {HOTELS}")

    data = json.loads(BASE.read_text(encoding="utf-8"))
    records = data.get("records", [])
    centers = data.get("centers", [])

    if not isinstance(records, list) or not isinstance(centers, list):
        raise SystemExit("Ana veri dosyası beklenen yapıda değil.")

    # Bilinen il/ilçe adları
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

    # Daha önce eklenmiş Otel kategorisini temizle; diğer kategorileri koru.
    cleaned = []
    existing_by_osm = {}
    removed_old_hotel_only = 0
    for r in records:
        cats = list(r.get("categories") or [])
        if "Otel" in cats:
            cats = [x for x in cats if x != "Otel"]
            if not cats:
                removed_old_hotel_only += 1
                continue
            r["categories"] = cats
        cleaned.append(r)
        try:
            existing_by_osm[(str(r.get("type")), int(r.get("id")))] = r
        except Exception:
            pass
    records = cleaned

    geo = json.loads(HOTELS.read_text(encoding="utf-8"))
    features = geo.get("features", [])
    added = 0
    merged = 0
    skipped = 0

    for f in features:
        ident = osm_identity(f)
        pt = representative_point(f.get("geometry"))
        if ident is None or pt is None:
            skipped += 1
            continue

        osm_type, osm_id = ident
        lat, lon = pt
        tags = clean_tags(f)

        # Açıkça otel değilse alma.
        if str(tags.get("tourism", "")).lower() != "hotel":
            continue

        key = (osm_type, osm_id)
        if key in existing_by_osm:
            r = existing_by_osm[key]
            cats = list(r.get("categories") or [])
            if "Otel" not in cats:
                cats.append("Otel")
                r["categories"] = cats
            # Otel kaynağındaki eksik olmayan ek bilgileri birleştir.
            rt = dict(r.get("tags") or {})
            for k, v in tags.items():
                if k not in rt or not str(rt.get(k, "")).strip():
                    rt[k] = v
            r["tags"] = rt
            merged += 1
            continue

        # Önce adres etiketlerinden il bulmaya çalış.
        raw_il = tags.get("addr:province") or tags.get("addr:state")
        il_key = norm(raw_il)
        il = province_names.get(il_key, "")

        raw_district = tags.get("addr:district")
        raw_city = tags.get("addr:city")

        ilce = ""
        if il:
            for candidate in (raw_district, raw_city):
                ck = norm(candidate)
                exact = district_names.get((norm(il), ck))
                if exact:
                    ilce = exact
                    break

        # Eksik idari alanlar için mevcut 965 ilçe merkezinden en yakınını kullan.
        candidates = centers_by_province.get(norm(il), usable_centers) if il else usable_centers
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

        records.append({
            "type": osm_type,
            "id": osm_id,
            "lat": round(lat, 7),
            "lon": round(lon, 7),
            "tags": tags,
            "categories": ["Otel"],
            "il": il,
            "ilce": ilce,
        })
        existing_by_osm[key] = records[-1]
        added += 1

    data["records"] = records
    data["hotelSource"] = "OpenStreetMap contributors / Geofabrik Turkey extract"
    data["hotelSourceUrl"] = "https://download.geofabrik.de/europe/turkey.html"
    data["hotelSnapshot"] = date.today().isoformat()
    data["hotelTag"] = "tourism=hotel"
    data["hotelAdminAssignment"] = (
        "OSM adres etiketleri kullanıldı; eksik il/ilçe alanlarında en yakın mevcut ilçe merkezi atandı."
    )

    BASE.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8"
    )

    print(f"Otel verisi tamamlandı. Yeni: {added}, mevcut kayda eklendi: {merged}, atlanan: {skipped}")
    print(f"Eski sadece-otel kayıt temizliği: {removed_old_hotel_only}")
    print(f"Toplam kayıt: {len(records)}")

if __name__ == "__main__":
    main()
