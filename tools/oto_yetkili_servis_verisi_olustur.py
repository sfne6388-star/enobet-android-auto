#!/usr/bin/env python3
import json
import math
import re
import unicodedata
from datetime import date
from pathlib import Path

BASE = Path("assets/data/turkiye_hizmetleri.json")
CANDIDATES = Path("/tmp/oto_yetkili_servis_adaylari.geojson")
CATEGORY = "Oto Yetkili Servis"

AUTH_TERMS = (
    "yetkili servis",
    "yetkili otomotiv",
    "yetkili satici",
    "yetkili satıcı",
    "yetkili bayi",
    "yetkili bayii",
    "yetkili satici ve servis",
    "yetkili satıcı ve servis",
    "authorized service",
    "authorised service",
    "authorized dealer",
    "authorised dealer",
    "official dealer",
    "official service",
)

# Marka bilgisi OSM'de açıkça bulunan kayıtlar için ikinci, temkinli yol.
CAR_BRANDS = (
    "abarth", "alfa romeo", "audi", "bmw", "byd", "chery", "chevrolet",
    "citroen", "citroën", "cupra", "dacia", "ds automobiles", "fiat",
    "ford", "honda", "hyundai", "isuzu", "jaguar", "jeep", "kia",
    "land rover", "lexus", "mazda", "mercedes", "mercedes benz", "mg",
    "mini", "mitsubishi", "nissan", "opel", "peugeot", "porsche",
    "renault", "seat", "skoda", "škoda", "subaru", "suzuki", "tesla",
    "toyota", "volkswagen", "vw", "volvo",
    "togg", "omoda", "jaecoo", "maxus", "skywell", "leapmotor",
    "dongfeng", "dfsk", "seres", "karsan", "iveco",
)

SERVICE_TERMS = (
    "servis", "service", "otomotiv", "plaza", "motors", "motorlu araclar",
    "motorlu araçlar", "bayi", "dealer", "satış ve servis", "satis ve servis",
    "yetkili", "authorized", "authorised", "sales and service",
    "service center", "service centre",
)

BLOCKED_TERMS = (
    "ozel servis", "özel servis", "special service", "independent service",
    "sanayi sitesi", "oto tamir", "kaporta boya", "lastik", "egzoz",
)


def norm(v):
    if v is None:
        return ""
    s = str(v).strip().lower().translate(
        str.maketrans(
            {
                "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
                "Ç": "c", "Ğ": "g", "İ": "i", "I": "i", "Ö": "o", "Ş": "s", "Ü": "u",
            }
        )
    )
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", s).split())


AUTH = tuple(norm(x) for x in AUTH_TERMS)
BRANDS = tuple(norm(x) for x in CAR_BRANDS)
SERVICES = tuple(norm(x) for x in SERVICE_TERMS)
BLOCKED = tuple(norm(x) for x in BLOCKED_TERMS)


def tags_of(f):
    p = dict(f.get("properties") or {})
    if isinstance(p.get("tags"), dict):
        return dict(p["tags"])
    return {
        k: v
        for k, v in p.items()
        if not str(k).startswith("@") and k not in {"id", "osm_id", "osm_type", "type"}
    }


def yes(tags, key):
    return norm(tags.get(key)) in {"yes", "true", "1"}


def contains_any(blob, terms):
    return any(t and t in blob for t in terms)


def is_authorized(tags):
    descriptive_blob = " ".join(
        norm(tags.get(k))
        for k in ("name", "official_name", "description", "operator", "brand", "note")
        if tags.get(k)
    )

    if contains_any(descriptive_blob, BLOCKED):
        return False

    # En güçlü kanıt: kaydın kendisinde açıkça yetkili/authorized ifadesi.
    if contains_any(descriptive_blob, AUTH):
        return True

    brand_blob = " ".join(
        norm(tags.get(k))
        for k in ("brand", "manufacturer", "operator", "name")
        if tags.get(k)
    )
    has_known_brand = contains_any(brand_blob, BRANDS)
    has_service_word = contains_any(descriptive_blob, SERVICES)
    repair_tag = yes(tags, "service:vehicle:repair")
    shop = norm(tags.get("shop"))

    # Branded car dealer + açık servis/onarım işareti güçlü bir resmi bayi/servis
    # göstergesidir. Sadece marka adı geçen bağımsız tamirciyi kabul etmiyoruz.
    if shop == "car" and has_known_brand and (repair_tag or has_service_word):
        return True

    # OSM'de bazı resmi otomobil bayileri servis bilgisini ayrı bir etikette
    # tutmuyor. shop=car + bilinen marka + bayi/dealer/plaza/otomotiv ifadesi
    # resmi satış/servis noktası için yeterince güçlü bir kanıttır.
    dealer_words = tuple(norm(x) for x in (
        "bayi", "bayii", "dealer", "plaza", "otomotiv",
        "yetkili", "authorized", "authorised",
    ))
    if shop == "car" and has_known_brand and contains_any(descriptive_blob, dealer_words):
        return True

    # car_repair kaydı için daha da sıkıyız: marka + servis/plaza/bayi ifadesi
    # ve repair etiketi birlikte olmalı.
    if shop == "car repair" and has_known_brand and repair_tag and has_service_word:
        return True

    return False


def points(g):
    if not g:
        return []
    c = g.get("coordinates")
    if g.get("type") == "Point":
        return [c] if isinstance(c, list) and len(c) >= 2 else []
    out = []

    def walk(x):
        if isinstance(x, list):
            if len(x) >= 2 and isinstance(x[0], (int, float)) and isinstance(x[1], (int, float)):
                out.append(x)
            else:
                for y in x:
                    walk(y)

    walk(c)
    return out


def rep(g):
    p = points(g)
    if not p:
        return None
    lat = sum(float(x[1]) for x in p) / len(p)
    lon = sum(float(x[0]) for x in p) / len(p)
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    return lat, lon


def identity(f):
    p = f.get("properties") or {}
    raw = str(f.get("id") or p.get("@id") or p.get("id") or "")
    if "/" in raw:
        t, i = raw.split("/", 1)
        if t in {"node", "way", "relation"}:
            try:
                return t, int(i)
            except Exception:
                pass
    t = p.get("@type") or p.get("osm_type") or "node"
    i = p.get("@id") or p.get("osm_id") or p.get("id")
    try:
        i = int(str(i).split("/")[-1])
    except Exception:
        return None
    return (t if t in {"node", "way", "relation"} else "node"), i


def dist(a, b, c, d):
    scale = math.cos(math.radians((a + c) / 2))
    return (a - c) ** 2 + ((b - d) * scale) ** 2


def main():
    data = json.loads(BASE.read_text(encoding="utf-8"))
    records = data["records"]
    centers = data["centers"]

    usable = []
    provinces = {}
    districts = {}
    centers_by_province = {}
    for c in centers:
        try:
            il = str(c["il"]).strip()
            ilce = str(c["ilce"]).strip()
            lat = float(c["lat"])
            lon = float(c["lon"])
        except Exception:
            continue
        usable.append((lat, lon, il, ilce))
        provinces[norm(il)] = il
        districts[(norm(il), norm(ilce))] = ilce
        centers_by_province.setdefault(norm(il), []).append((lat, lon, il, ilce))

    # Eski üretimi temizle, başka kategorileri koru.
    cleaned = []
    existing = {}
    for r in records:
        cats = list(r.get("categories") or [])
        if CATEGORY in cats:
            cats = [x for x in cats if x != CATEGORY]
            if not cats:
                continue
            r["categories"] = cats
        cleaned.append(r)
        try:
            existing[(str(r.get("type")), int(r.get("id")))] = r
        except Exception:
            pass
    records = cleaned

    geo = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    added = merged = filtered = skipped = 0

    keep_keys = {
        "name", "official_name", "brand", "manufacturer", "operator", "phone",
        "contact:phone", "website", "contact:website", "opening_hours",
        "description", "note", "addr:street", "addr:housenumber",
        "addr:neighbourhood", "addr:suburb", "addr:district", "addr:city",
        "addr:province", "addr:state", "addr:postcode", "shop", "amenity",
        "service:vehicle:repair", "service:vehicle", "car", "second_hand",
    }

    for f in geo.get("features", []):
        tags = tags_of(f)
        if not is_authorized(tags):
            filtered += 1
            continue

        ident = identity(f)
        pos = rep(f.get("geometry"))
        if ident is None or pos is None:
            skipped += 1
            continue

        lat, lon = pos
        tags = {k: v for k, v in tags.items() if k in keep_keys and str(v).strip()}
        key = ident

        if key in existing:
            r = existing[key]
            cats = list(r.get("categories") or [])
            if CATEGORY not in cats:
                cats.append(CATEGORY)
            r["categories"] = cats
            old = dict(r.get("tags") or {})
            for k, v in tags.items():
                if not str(old.get(k, "")).strip():
                    old[k] = v
            r["tags"] = old
            merged += 1
            continue

        raw_il = tags.get("addr:province") or tags.get("addr:state")
        il = provinces.get(norm(raw_il), "")
        ilce = ""
        if il:
            for v in (tags.get("addr:district"), tags.get("addr:city")):
                x = districts.get((norm(il), norm(v)))
                if x:
                    ilce = x
                    break

        candidates = centers_by_province.get(norm(il), usable) if il else usable
        if not candidates:
            candidates = usable
        nearest = min(candidates, key=lambda c: dist(lat, lon, c[0], c[1])) if candidates else None
        if nearest:
            if not il:
                il = nearest[2]
            if not ilce:
                ilce = nearest[3]
        if not il or not ilce:
            skipped += 1
            continue

        r = {
            "type": ident[0],
            "id": ident[1],
            "lat": round(lat, 7),
            "lon": round(lon, 7),
            "tags": tags,
            "categories": [CATEGORY],
            "il": il,
            "ilce": ilce,
        }
        records.append(r)
        existing[key] = r
        added += 1

    data["records"] = records
    data["otoYetkiliServisSource"] = "OpenStreetMap contributors / Geofabrik Turkey extract"
    data["otoYetkiliServisSnapshot"] = date.today().isoformat()
    data["otoYetkiliServisFilter"] = (
        "Açık yetkili/authorized servis ifadesi bulunan kayıtlar; ayrıca bilinen "
        "otomobil markası ile birlikte branded car dealer + repair/service kanıtı "
        "bulunan kayıtlar. Bağımsız/özel tamirciler temkinli biçimde dışlanır."
    )
    BASE.write_text(
        json.dumps(data, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    total = sum(1 for r in records if CATEGORY in (r.get("categories") or []))
    province_count = len(
        {r.get("il", "") for r in records if CATEGORY in (r.get("categories") or []) and r.get("il")}
    )
    print("Yeni:", added, "Mevcut kayda eklendi:", merged, "Filtre dışı:", filtered, "Atlanan:", skipped)
    print("Toplam Oto Yetkili Servis kaydı:", total)
    print("Kayıt bulunan il sayısı:", province_count)
    if total == 0:
        raise SystemExit("HATA: Oto Yetkili Servis kaydı oluşmadı.")


if __name__ == "__main__":
    main()
