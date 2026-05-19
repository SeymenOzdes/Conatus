import asyncpg

from schemas.spots import SpotResult

_BY_ID_SQL = """
SELECT id, name, lat, lng, region
FROM surf_spots_v2
WHERE id = $1;
"""

_TEXT_SQL = """
SELECT id, name, lat, lng, region
FROM surf_spots_v2
WHERE to_tsvector('simple', name) @@ plainto_tsquery('simple', $1)
   OR name ILIKE $2
ORDER BY
  ts_rank(to_tsvector('simple', name), plainto_tsquery('simple', $1)) DESC,
  name ASC
LIMIT $3;
"""

# ST_MakePoint is (lng, lat) — Postgres convention is x, y.
_GEO_SQL = """
SELECT
  id, name, lat, lng, region,
  ST_Distance(
    location,
    ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
  )::int AS distance_m
FROM surf_spots_v2
WHERE ST_DWithin(
  location,
  ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
  $3
)
ORDER BY distance_m ASC
LIMIT $4;
"""


async def get_spot_by_id(pool: asyncpg.Pool, spot_id: str) -> dict | None:
    async with pool.acquire() as conn:
        row = await conn.fetchrow(_BY_ID_SQL, spot_id)
    if row is None:
        return None
    return {
        "id": row["id"],
        "name": row["name"],
        "lat": row["lat"],
        "lng": row["lng"],
        "region": row["region"],
    }


async def search_by_text(pool: asyncpg.Pool, q: str, limit: int) -> list[SpotResult]:
    async with pool.acquire() as conn:
        rows = await conn.fetch(_TEXT_SQL, q, f"{q}%", limit)
    return [
        SpotResult(
            spot_id=r["id"],
            name=r["name"],
            lat=r["lat"],
            lng=r["lng"],
            break_type=None,
            country=r["region"],
        )
        for r in rows
    ]


async def search_by_geo(
    pool: asyncpg.Pool,
    lat: float,
    lng: float,
    radius_m: int,
    limit: int,
) -> list[SpotResult]:
    async with pool.acquire() as conn:
        rows = await conn.fetch(_GEO_SQL, lat, lng, radius_m, limit)
    return [
        SpotResult(
            spot_id=r["id"],
            name=r["name"],
            lat=r["lat"],
            lng=r["lng"],
            break_type=None,
            country=r["region"],
            distance_m=r["distance_m"],
        )
        for r in rows
    ]
