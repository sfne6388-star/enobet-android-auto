#!/usr/bin/env python3
import hashlib
import json
import math
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

MAJOR_CLASSES = {
    "motorway", "motorway_link",
    "trunk", "trunk_link",
    "primary", "primary_link",
    "secondary", "secondary_link",
}
CELL_DEG = 0.03


def iter_geojsonseq(path):
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def feature_tags(feature):
    props = feature.get("properties") or {}
    tags = props.get("tags")
    if isinstance(tags, dict):
        merged = dict(tags)
        for k, v in props.items():
            if k != "tags" and k not in merged:
                merged[k] = v
        return merged
    return dict(props)


def feature_osm_identity(feature, tags=None):
    """Return a stable OSM identity.

    `osmium export` does not export OSM type/id attributes unless explicitly
    requested. The workflow now exports them with `--attributes=type,id`, but
    keep a deterministic fallback so one missing attribute can never collapse
    the whole catalogue into a single `(node, None)` record again.
    """
    props = feature.get("properties") or {}
    osm_type = props.get("@type") or props.get("type") or "node"
    osm_id = props.get("@id") or props.get("id") or feature.get("id")

    if isinstance(osm_id, str):
        raw_id = osm_id.strip()
        if "/" in raw_id:
            prefix, raw = raw_id.rsplit("/", 1)
            osm_type = prefix or osm_type
            osm_id = int(raw) if raw.isdigit() else raw
        elif len(raw_id) > 1 and raw_id[0] in "nwra" and raw_id[1:].lstrip("-").isdigit():
            osm_type = {"n": "node", "w": "way", "r": "relation", "a": "area"}[raw_id[0]]
            osm_id = int(raw_id[1:])
        elif raw_id.lstrip("-").isdigit():
            osm_id = int(raw_id)

    if osm_id is None or str(osm_id).strip() in {"", "None"}:
        payload = {
            "geometry": feature.get("geometry"),
            "tags": tags if isinstance(tags, dict) else feature_tags(feature),
        }
        digest = hashlib.sha1(
            json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest()[:20]
        osm_type = str(osm_type or "feature")
        osm_id = f"fallback-{digest}"

    return str(osm_type), osm_id


def flatten_points(geometry):
    if not geometry:
        return []
    typ = geometry.get("type")
    coords = geometry.get("coordinates")
    if typ == "Point":
        return [coords] if coords and len(coords) >= 2 else []
    if typ in ("LineString", "MultiPoint"):
        return coords or []
    if typ == "Polygon":
        return (coords or [[]])[0]
    if typ == "MultiLineString":
        out = []
        for line in coords or []:
            out.extend(line)
        return out
    if typ == "MultiPolygon":
        out = []
        for polygon in coords or []:
            if polygon:
                out.extend(polygon[0])
        return out
    return []


def representative_point(feature):
    pts = flatten_points(feature.get("geometry"))
    if not pts:
        return None
    xs = [float(p[0]) for p in pts if len(p) >= 2]
    ys = [float(p[1]) for p in pts if len(p) >= 2]
    if not xs or not ys:
        return None
    return sum(xs) / len(xs), sum(ys) / len(ys)


def segment_projection(px, py, ax, ay, bx, by):
    mean_lat = math.radians((py + ay + by) / 3.0)
    mlat = 111320.0
    mlon = 111320.0 * math.cos(mean_lat)
    axm, aym = ax * mlon, ay * mlat
    bxm, bym = bx * mlon, by * mlat
    pxm, pym = px * mlon, py * mlat
    dx, dy = bxm - axm, bym - aym
    denom = dx * dx + dy * dy
    if denom <= 0:
        return math.hypot(pxm - axm, pym - aym), 0.0, 0.0
    t = ((pxm - axm) * dx + (pym - aym) * dy) / denom
    t = max(0.0, min(1.0, t))
    qx, qy = axm + t * dx, aym + t * dy
    vx, vy = pxm - qx, pym - qy
    cross = dx * (pym - aym) - dy * (pxm - axm)
    return math.hypot(vx, vy), t, cross


def build_road_index(path):
    grid = defaultdict(list)
    roads = segments = 0
    for feature in iter_geojsonseq(path):
        tags = feature_tags(feature)
        highway = str(tags.get("highway") or "").strip()
        if highway not in MAJOR_CLASSES:
            continue
        ref = str(tags.get("ref") or "").strip()
        name = str(tags.get("name") or "").strip()
        if highway.startswith(("primary", "secondary")) and not ref:
            continue
        oneway_value = str(tags.get("oneway") or "").lower().strip()
        oneway = oneway_value in {"yes", "1", "true", "-1"}
        reverse = oneway_value == "-1"
        geometry = feature.get("geometry") or {}
        typ = geometry.get("type")
        coords = geometry.get("coordinates") or []
        lines = [coords] if typ == "LineString" else coords if typ == "MultiLineString" else []
        if not lines:
            continue
        roads += 1
        for line in lines:
            for a, b in zip(line, line[1:]):
                if len(a) < 2 or len(b) < 2:
                    continue
                ax, ay = float(a[0]), float(a[1])
                bx, by = float(b[0]), float(b[1])
                if reverse:
                    ax, ay, bx, by = bx, by, ax, ay
                road = {
                    "ax": ax, "ay": ay, "bx": bx, "by": by,
                    "highway": highway,
                    "ref": ref,
                    "name": name,
                    "oneway": oneway,
                    "junction": str(tags.get("junction") or ""),
                }
                min_cx = math.floor(min(ax, bx) / CELL_DEG)
                max_cx = math.floor(max(ax, bx) / CELL_DEG)
                min_cy = math.floor(min(ay, by) / CELL_DEG)
                max_cy = math.floor(max(ay, by) / CELL_DEG)
                for cx in range(min_cx, max_cx + 1):
                    for cy in range(min_cy, max_cy + 1):
                        grid[(cx, cy)].append(road)
                segments += 1
    print("Ana yol:", roads)
    print("Yol segmenti:", segments)
    return grid


def nearest_road(grid, lon, lat):
    cx = math.floor(lon / CELL_DEG)
    cy = math.floor(lat / CELL_DEG)
    best = None
    seen = set()
    for radius in range(4):
        for x in range(cx - radius, cx + radius + 1):
            for y in range(cy - radius, cy + radius + 1):
                for road in grid.get((x, y), []):
                    rid = id(road)
                    if rid in seen:
                        continue
                    seen.add(rid)
                    d, t, cross = segment_projection(
                        lon, lat,
                        road["ax"], road["ay"],
                        road["bx"], road["by"],
                    )
                    if best is None or d < best[0]:
                        best = (d, t, cross, road)
        if best is not None and best[0] < 180:
            break
    return best


def service_type(tags):
    amenity = str(tags.get("amenity") or "")
    highway = str(tags.get("highway") or "")
    if highway in {"services", "rest_area"}:
        return "dinlenme"
    if amenity == "fuel":
        return "akaryakit"
    if amenity == "charging_station":
        return "sarj"
    return None


def accepted(kind, distance_m, road):
    highway = road["highway"]
    ref = str(road.get("ref") or "").strip()
    divided = highway.startswith(("motorway", "trunk"))

    if kind == "dinlenme":
        limit = 320 if divided else 150
    else:
        limit = 150 if divided else 95

    if highway.startswith(("primary", "secondary")) and not ref:
        return False
    return distance_m <= limit


def pick_name(tags, kind):
    name = str(tags.get("name") or tags.get("brand") or tags.get("operator") or "").strip()
    if name:
        return name
    return {
        "akaryakit": "Akaryakıt İstasyonu",
        "sarj": "Elektrikli Şarj İstasyonu",
        "dinlenme": "Dinlenme Tesisi",
    }[kind]


def main():
    if len(sys.argv) != 4:
        raise SystemExit(
            "Kullanim: yol_hizmetleri_uret.py "
            "<hizmetler.geojsonseq> <yollar.geojsonseq> "
            "<yol_hizmetleri.json>"
        )

    services_path = Path(sys.argv[1])
    roads_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3])

    grid = build_road_index(roads_path)
    counts = defaultdict(int)
    raw_counts = defaultdict(int)
    matched_road_counts = defaultdict(int)
    rejected_distance_counts = defaultdict(int)
    fallback_identity_count = 0
    records = []
    seen = set()

    for feature in iter_geojsonseq(services_path):
        tags = feature_tags(feature)
        kind = service_type(tags)
        if kind is None:
            continue
        raw_counts[kind] += 1

        point = representative_point(feature)
        if point is None:
            continue
        lon, lat = point

        nearest = nearest_road(grid, lon, lat)
        if nearest is None:
            continue

        distance_m, projection_t, cross, road = nearest
        matched_road_counts[kind] += 1
        if not accepted(kind, distance_m, road):
            rejected_distance_counts[kind] += 1
            continue

        osm_type, osm_id = feature_osm_identity(feature, tags)
        if isinstance(osm_id, str) and osm_id.startswith("fallback-"):
            fallback_identity_count += 1
        key = (str(osm_type), str(osm_id))
        if key in seen:
            continue
        seen.add(key)

        records.append({
            "id": f"{osm_type}-{osm_id}",
            "osmType": osm_type,
            "osmId": osm_id,
            "name": pick_name(tags, kind),
            "brand": str(tags.get("brand") or tags.get("operator") or "").strip(),
            "lat": round(float(lat), 7),
            "lon": round(float(lon), 7),
            "tur": kind,
            "roadClass": road["highway"],
            "roadRef": road.get("ref") or "",
            "roadName": road.get("name") or "",
            "roadDistanceM": round(distance_m, 1),
            "roadOneway": bool(road.get("oneway")),
            "roadJunction": road.get("junction") or "",
            "roadSide": "left" if cross > 0 else "right" if cross < 0 else "center",
            "roadSegment": [
                round(road["ay"], 7), round(road["ax"], 7),
                round(road["by"], 7), round(road["bx"], 7),
            ],
            "roadProjection": round(projection_t, 5),
        })
        counts[kind] += 1

    records.sort(key=lambda r: (r["lat"], r["lon"], r["id"]))
    data = {
        "version": 4,
        "source": "OpenStreetMap contributors / Geofabrik Turkey extract",
        "sourceUrl": "https://download.geofabrik.de/europe/turkey.html",
        "license": "ODbL-1.0",
        "attribution": "© OpenStreetMap contributors",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "recordCount": len(records),
        "counts": dict(counts),
        "records": records,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    print("Ham hizmet adaylari:", dict(raw_counts))
    print("Ana yola eslesen adaylar:", dict(matched_road_counts))
    print("Mesafe filtresinde elenenler:", dict(rejected_distance_counts))
    print("Fallback kimlik kullanilan:", fallback_identity_count)
    print("Toplam Yol Asistani kaydi:", len(records))
    for key in ("akaryakit", "sarj", "dinlenme"):
        print(f"{key}: {counts[key]}")

    if sum(raw_counts.values()) < 250:
        raise SystemExit("HATA: OSM hizmet adaylari beklenenden az; cikarma adimini kontrol edin.")
    if len(records) < 250:
        raise SystemExit("HATA: Yol Asistani kayit sayisi cok az.")
    if counts["akaryakit"] < 100 or counts["dinlenme"] < 20:
        raise SystemExit("HATA: Yol Asistani kategori kapsami yetersiz.")


if __name__ == "__main__":
    main()
