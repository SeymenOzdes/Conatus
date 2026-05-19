"""
load_new_surf_spots.py
────────────────────────────────────────────────────────────────
Loads ConatusBackend/newSurfSpots.json into the surf_spots_v2 table.

Input rows are shaped: {"name", "country", "lat", "lng"} with lat/lng as
strings and `country` a hierarchical region label like
"USA, South East, North Florida" (not an ISO-2 code).

Row IDs are deterministic: f"v2_{slug(name)}_{sha1(lat,lng)[:8]}"

Usage:
  uv run python load_new_surf_spots.py

Env:
  DATABASE_URL=postgresql://user:pass@localhost:5432/surfapp
"""

import hashlib
import json
import logging
import os
import re
import time
from collections import Counter
from pathlib import Path

import psycopg2
import psycopg2.extras
from tqdm import tqdm

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/surfapp",
)

JSON_PATH = Path(__file__).parent / "newSurfSpots.json"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger(__name__)


_SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(name: str, max_len: int = 60) -> str:
    s = _SLUG_RE.sub("-", name.lower()).strip("-")
    return s[:max_len] or "spot"


def coord_hash(lat: float, lng: float) -> str:
    return hashlib.sha1(f"{lat:.6f},{lng:.6f}".encode()).hexdigest()[:8]


def build_row(entry: dict) -> dict | None:
    name = (entry.get("name") or "").strip()
    if not name:
        return None

    try:
        lat = float(entry["lat"])
        lng = float(entry["lng"])
    except (KeyError, TypeError, ValueError):
        return None

    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        return None

    region = (entry.get("country") or "").strip() or None

    return {
        "id": f"v2_{slugify(name)}_{coord_hash(lat, lng)}",
        "name": name,
        "lat": lat,
        "lng": lng,
        "region": region,
    }


def load_rows(path: Path) -> list[dict]:
    log.info(f"Reading {path.name}...")
    with path.open() as f:
        raw = json.load(f)

    seen_ids: set[str] = set()
    rows: list[dict] = []
    skipped = {"bad_name": 0, "bad_coords": 0, "dup_id": 0}

    for entry in raw:
        row = build_row(entry)
        if row is None:
            name = (entry.get("name") or "").strip()
            if not name:
                skipped["bad_name"] += 1
            else:
                skipped["bad_coords"] += 1
            continue

        if row["id"] in seen_ids:
            skipped["dup_id"] += 1
            continue
        seen_ids.add(row["id"])
        rows.append(row)

    log.info(
        f"Parsed {len(rows)} rows "
        f"(skipped — bad_name: {skipped['bad_name']}, "
        f"bad_coords: {skipped['bad_coords']}, dup_id: {skipped['dup_id']})"
    )
    return rows


SCHEMA_SQL = """
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS surf_spots_v2 (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    location    GEOGRAPHY(POINT, 4326),
    region      TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS surf_spots_v2_location_idx
    ON surf_spots_v2 USING GIST (location);

CREATE INDEX IF NOT EXISTS surf_spots_v2_name_idx
    ON surf_spots_v2 USING GIN (to_tsvector('simple', name));

CREATE INDEX IF NOT EXISTS surf_spots_v2_region_idx
    ON surf_spots_v2 (region);
"""

INSERT_SQL = """
INSERT INTO surf_spots_v2 (id, name, lat, lng, location, region)
VALUES (
    %(id)s, %(name)s, %(lat)s, %(lng)s,
    ST_SetSRID(ST_MakePoint(%(lng)s, %(lat)s), 4326),
    %(region)s
)
ON CONFLICT (id) DO UPDATE SET
    name       = EXCLUDED.name,
    lat        = EXCLUDED.lat,
    lng        = EXCLUDED.lng,
    location   = EXCLUDED.location,
    region     = EXCLUDED.region,
    updated_at = NOW();
"""


def insert_rows(rows: list[dict]) -> None:
    safe_url = DATABASE_URL.split("@")[-1]
    log.info(f"Connecting to PostgreSQL: {safe_url}")
    conn = psycopg2.connect(DATABASE_URL)
    try:
        with conn.cursor() as cur:
            log.info("Applying schema...")
            cur.execute(SCHEMA_SQL)
            conn.commit()

            BATCH = 500
            for i in tqdm(range(0, len(rows), BATCH), desc="Inserting"):
                batch = rows[i : i + BATCH]
                psycopg2.extras.execute_batch(cur, INSERT_SQL, batch)
                conn.commit()
    finally:
        conn.close()

    log.info(f"Inserted {len(rows)} rows into surf_spots_v2.")


def print_summary(rows: list[dict]) -> None:
    regions = Counter(r["region"] for r in rows if r["region"])
    print("\n" + "═" * 50)
    print(f"  Total rows:       {len(rows)}")
    print(f"  Distinct regions: {len(regions)}")
    print("  Top regions:")
    for region, count in regions.most_common(10):
        print(f"    {region}: {count}")
    print("═" * 50 + "\n")


def main() -> None:
    start = time.time()
    log.info("=== Loading newSurfSpots.json → surf_spots_v2 ===")

    rows = load_rows(JSON_PATH)
    print_summary(rows)
    insert_rows(rows)

    log.info(f"=== Done ({time.time() - start:.1f}s) ===")


if __name__ == "__main__":
    main()
