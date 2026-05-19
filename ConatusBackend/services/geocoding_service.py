"""Nominatim-backed place-name geocoder with an in-process TTL cache.

Used as a fallback in /v1/spots/search: when the DB text query returns no
rows, we ask Nominatim for the query's coordinates and re-run the search as
a proximity query against surf_spots_v2.

Cache policy:
- Positive hits: 30 days. Coordinates of named places don't drift.
- Negative hits ("not found"): 1 hour. Avoids hammering Nominatim with
  typos while still giving the world time to add new places.

Concurrency: a single asyncio.Lock around the cache + upstream call so that
N concurrent identical queries collapse to one outbound request.
"""

from __future__ import annotations

import asyncio
import logging
import time
import unicodedata

import httpx

log = logging.getLogger(__name__)

_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
_USER_AGENT = "Conatus/0.1 (ozdesxseymen@gmail.com)"
_HTTP_TIMEOUT_S = 5.0

_POSITIVE_TTL_S = 30 * 24 * 60 * 60
_NEGATIVE_TTL_S = 60 * 60

_client: httpx.AsyncClient | None = None
_cache: dict[str, tuple[tuple[float, float] | None, float]] = {}
_lock = asyncio.Lock()


async def startup() -> None:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=_HTTP_TIMEOUT_S,
            headers={"User-Agent": _USER_AGENT},
        )


async def shutdown() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


def _normalize(name: str) -> str:
    folded = name.strip().casefold()
    decomposed = unicodedata.normalize("NFKD", folded)
    return decomposed.encode("ascii", "ignore").decode("ascii")


async def geocode_place(name: str) -> tuple[float, float] | None:
    key = _normalize(name)
    if not key:
        return None

    now = time.monotonic()
    cached = _cache.get(key)
    if cached is not None and cached[1] > now:
        return cached[0]

    async with _lock:
        cached = _cache.get(key)
        if cached is not None and cached[1] > time.monotonic():
            return cached[0]

        coords = await _fetch_from_nominatim(name)
        ttl = _POSITIVE_TTL_S if coords is not None else _NEGATIVE_TTL_S
        _cache[key] = (coords, time.monotonic() + ttl)
        return coords


async def _fetch_from_nominatim(name: str) -> tuple[float, float] | None:
    if _client is None:
        log.warning("geocode_place called before startup()")
        return None

    try:
        resp = await _client.get(
            _NOMINATIM_URL,
            params={"q": name, "format": "json", "limit": 1, "addressdetails": 0},
        )
    except httpx.HTTPError as exc:
        log.warning("nominatim request failed for %r: %s", name, exc)
        return None

    if resp.status_code != 200:
        log.warning("nominatim non-200 for %r: %s", name, resp.status_code)
        return None

    try:
        payload = resp.json()
    except ValueError:
        log.warning("nominatim non-JSON response for %r", name)
        return None

    if not isinstance(payload, list) or not payload:
        return None

    try:
        lat = float(payload[0]["lat"])
        lng = float(payload[0]["lon"])
    except (KeyError, TypeError, ValueError):
        return None

    if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
        return None

    return lat, lng
