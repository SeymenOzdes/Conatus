"""
fetch_surf_spots.py
────────────────────────────────────────────────────────────────
OpenStreetMap Overpass API → PostgreSQL

Adımlar:
  1. Overpass'tan tüm surfing node'larını çek
  2. Temizle (isimsiz, duplikat, geçersiz koordinat)
  3. PostgreSQL'e bas
  4. Özet rapor yaz

Gereksinimler:
  pip install requests psycopg2-binary tqdm

Kullanım:
  python fetch_surf_spots.py

Ortam değişkenleri (.env veya export ile):
  DATABASE_URL=postgresql://user:pass@localhost:5432/surfapp
"""

import json
import os
import time
import math
import logging
from datetime import datetime

import requests
import psycopg2
import psycopg2.extras
from tqdm import tqdm

# ─── Config ───────────────────────────────────────────────────

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/surfapp"
)

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# OSM'de surfing ile ilişkili tüm tag kombinasyonları
OVERPASS_QUERY = """
[out:json][timeout:120];
(
  node["sport"="surfing"];
  node["sport"="surf"];
  node["sport"="body_boarding"];
  way["sport"="surfing"];
  way["sport"="surf"];
  way["natural"="beach"]["sport"="surfing"];
  relation["sport"="surfing"];
);
out center body;
"""

# Duplikat tespiti: aynı isim + bu mesafe içinde → merge et
DUPLICATE_RADIUS_KM = 0.3

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


# ─── 1. Overpass'tan Çek ──────────────────────────────────────

def fetch_from_overpass() -> list[dict]:
    """Ham OSM elementlerini döner."""
    log.info("Overpass API'ye istek atılıyor...")

    try:
        resp = requests.post(
            OVERPASS_URL,
            data={"data": OVERPASS_QUERY},
            timeout=120,
            headers={"User-Agent": "SurfApp/1.0 (data-pipeline)"},
        )
        resp.raise_for_status()
    except requests.exceptions.Timeout:
        log.error("Overpass zaman aşımı. Tekrar dene veya mirror kullan.")
        raise
    except requests.exceptions.HTTPError as e:
        log.error(f"Overpass HTTP hatası: {e}")
        raise

    data = resp.json()
    elements = data.get("elements", [])
    log.info(f"Overpass'tan {len(elements)} element geldi.")
    return elements


# ─── 2. Temizle ───────────────────────────────────────────────

def haversine_km(lat1, lng1, lat2, lng2) -> float:
    """İki koordinat arasındaki mesafeyi km olarak döner."""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) *
         math.cos(math.radians(lat2)) *
         math.sin(dlng / 2) ** 2)
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def extract_name(tags: dict) -> str | None:
    """OSM tag'larından en iyi ismi çeker."""
    for key in ["name", "name:en", "official_name", "alt_name"]:
        val = tags.get(key, "").strip()
        if val:
            return val
    return None


def extract_coords(el: dict) -> tuple[float, float] | None:
    """Node veya way center koordinatını döner."""
    if el["type"] == "node":
        return el.get("lat"), el.get("lon")
    if el["type"] == "way":
        center = el.get("center", {})
        return center.get("lat"), center.get("lon")
    return None, None


def clean_elements(elements: list[dict]) -> list[dict]:
    """
    Temizleme adımları:
      - İsimsiz node'ları at
      - Koordinatsız / geçersiz koordinatlı node'ları at
      - Duplikatları kaldır (mesafe bazlı)
    """
    stats = {"no_name": 0, "bad_coords": 0, "duplicate": 0, "ok": 0}
    cleaned = []

    for el in tqdm(elements, desc="Temizleniyor"):
        tags = el.get("tags", {})

        # İsim kontrolü
        name = extract_name(tags)
        if not name:
            stats["no_name"] += 1
            continue

        # Koordinat kontrolü
        lat, lng = extract_coords(el)
        if lat is None or lng is None:
            stats["bad_coords"] += 1
            continue
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            stats["bad_coords"] += 1
            continue

        # Duplikat kontrolü: aynı isim + DUPLICATE_RADIUS_KM içinde
        is_dup = False
        for existing in cleaned:
            if existing["name"].lower() == name.lower():
                dist = haversine_km(lat, lng, existing["lat"], existing["lng"])
                if dist < DUPLICATE_RADIUS_KM:
                    is_dup = True
                    break
        if is_dup:
            stats["duplicate"] += 1
            continue

        country = (
            tags.get("addr:country") or
            tags.get("is_in:country_code") or
            tags.get("country_code")
        )

        cleaned.append({
            "osm_id": el["id"],
            "osm_type": el["type"],
            "name": name,
            "lat": lat,
            "lng": lng,
            "country": country[:2].upper() if country else None,
            "break_type": tags.get("surf:break_type"),       # opsiyonel OSM tag
            "difficulty": None,                               # sonra crowd-source
            "website": tags.get("website") or tags.get("url"),
            "raw_tags": json.dumps(tags),
        })
        stats["ok"] += 1

    log.info(
        f"Temizleme tamamlandı — "
        f"geçerli: {stats['ok']}, "
        f"isimsiz: {stats['no_name']}, "
        f"kötü koordinat: {stats['bad_coords']}, "
        f"duplikat: {stats['duplicate']}"
    )
    return cleaned


# ─── 3. PostgreSQL'e Bas ──────────────────────────────────────

SCHEMA_SQL = """
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS spots (
    id              TEXT PRIMARY KEY,           -- "osm_123456789"
    name            TEXT NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lng             DOUBLE PRECISION NOT NULL,
    location        GEOGRAPHY(POINT, 4326),     -- PostGIS kolon
    country         CHAR(2),
    break_type      TEXT,                        -- beach_break / reef_break / point_break
    difficulty      INT CHECK (difficulty BETWEEN 1 AND 5),
    website         TEXT,
    closest_buoy_id TEXT,                        -- NOAA station ID (sonra doldurulur)
    raw_tags        JSONB,
    osm_id          BIGINT UNIQUE,
    osm_type        TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Coğrafi sorgular için index (nearby spots)
CREATE INDEX IF NOT EXISTS spots_location_idx
    ON spots USING GIST (location);

-- İsim araması için index (Typesense'e ek olarak basit fallback)
CREATE INDEX IF NOT EXISTS spots_name_idx
    ON spots USING GIN (to_tsvector('simple', name));

-- Ülke filtresi için
CREATE INDEX IF NOT EXISTS spots_country_idx
    ON spots (country);
"""

INSERT_SQL = """
INSERT INTO spots (
    id, name, lat, lng, location, country,
    break_type, difficulty, website, raw_tags,
    osm_id, osm_type
)
VALUES (
    %(id)s, %(name)s, %(lat)s, %(lng)s,
    ST_SetSRID(ST_MakePoint(%(lng)s, %(lat)s), 4326),
    %(country)s, %(break_type)s, %(difficulty)s,
    %(website)s, %(raw_tags)s,
    %(osm_id)s, %(osm_type)s
)
ON CONFLICT (id) DO UPDATE SET
    name        = EXCLUDED.name,
    lat         = EXCLUDED.lat,
    lng         = EXCLUDED.lng,
    location    = EXCLUDED.location,
    country     = EXCLUDED.country,
    raw_tags    = EXCLUDED.raw_tags,
    updated_at  = NOW();
"""


def insert_to_postgres(spots: list[dict]) -> None:
    log.info(f"PostgreSQL'e bağlanılıyor: {DATABASE_URL.split('@')[-1]}")
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    # Schema oluştur
    log.info("Schema oluşturuluyor...")
    cur.execute(SCHEMA_SQL)
    conn.commit()

    # Toplu insert (batch 500)
    BATCH = 500
    inserted = 0

    for i in tqdm(range(0, len(spots), BATCH), desc="PostgreSQL'e yazılıyor"):
        batch = spots[i:i + BATCH]
        rows = [{**s, "id": f"osm_{s['osm_id']}"} for s in batch]
        psycopg2.extras.execute_batch(cur, INSERT_SQL, rows)
        conn.commit()
        inserted += len(batch)

    cur.close()
    conn.close()
    log.info(f"Toplam {inserted} spot yazıldı.")


# ─── 4. Özet Rapor ────────────────────────────────────────────

def print_summary(spots: list[dict]) -> None:
    from collections import Counter
    countries = Counter(s["country"] for s in spots if s["country"])
    print("\n" + "═" * 50)
    print(f"  Toplam spot: {len(spots)}")
    print(f"  Ülke sayısı: {len(countries)}")
    print(f"  En fazla spot:")
    for country, count in countries.most_common(10):
        print(f"    {country}: {count}")
    print("═" * 50 + "\n")


# ─── Ana akış ─────────────────────────────────────────────────

def main():
    start = time.time()
    log.info("=== Surf Spot ETL başlıyor ===")

    elements = fetch_from_overpass()
    spots = clean_elements(elements)

    print_summary(spots)
    insert_to_postgres(spots)

    elapsed = time.time() - start
    log.info(f"=== Tamamlandı ({elapsed:.1f}s) ===")


if __name__ == "__main__":
    main()