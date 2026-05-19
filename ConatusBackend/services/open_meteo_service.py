"""Open-Meteo backed marine + weather conditions fetcher.

Used by GET /v1/spots/{spot_id}/conditions: looks up the spot's stored
(lat, lng) and asks Open-Meteo for current and 24-hour-forecast marine
+ weather data. No API key required.

Cache policy: 30 minutes per rounded (lat, lng) cell — Open-Meteo updates
hourly, and rounding to ~110m granularity keeps neighboring spots from
each triggering an upstream fetch.

Concurrency: a single asyncio.Lock so N concurrent identical lookups
collapse to one outbound pair of requests.

Inland / no-coverage handling: if the marine API returns an error or a
fully-null wave_height array, fetch_conditions() returns None and the
endpoint surfaces { "conditions": null, "error": "..." }.
"""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import datetime, timezone
from typing import Any

import httpx

log = logging.getLogger(__name__)

_MARINE_URL = "https://marine-api.open-meteo.com/v1/marine"
_FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
_USER_AGENT = "Conatus/0.1 (ozdesxseymen@gmail.com)"
_HTTP_TIMEOUT_S = 5.0
_CACHE_TTL_S = 30 * 60
_FORECAST_HOURS = 24

_MARINE_HOURLY = (
    "wave_height,wave_period,wave_direction,"
    "swell_wave_height,swell_wave_period,swell_wave_direction,"
    "sea_surface_temperature"
)
_MARINE_CURRENT = "wave_height,wave_period,wave_direction,sea_surface_temperature"

_FORECAST_CURRENT = (
    "temperature_2m,weather_code,"
    "wind_speed_10m,wind_direction_10m,wind_gusts_10m"
)
_FORECAST_HOURLY = (
    "temperature_2m,precipitation,weather_code,"
    "wind_speed_10m,wind_direction_10m"
)

_client: httpx.AsyncClient | None = None
_cache: dict[tuple[float, float], tuple[dict[str, Any], float]] = {}
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


async def fetch_conditions(lat: float, lng: float) -> dict[str, Any] | None:
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
        return None

    key = (round(lat, 3), round(lng, 3))
    now = time.monotonic()

    cached = _cache.get(key)
    if cached is not None and cached[1] > now:
        return cached[0]

    async with _lock:
        cached = _cache.get(key)
        if cached is not None and cached[1] > time.monotonic():
            return cached[0]

        data = await _fetch_from_open_meteo(lat, lng)
        if data is None:
            return None

        _cache[key] = (data, time.monotonic() + _CACHE_TTL_S)
        return data


async def _fetch_from_open_meteo(lat: float, lng: float) -> dict[str, Any] | None:
    if _client is None:
        log.warning("fetch_conditions called before startup()")
        return None

    marine_task = _get_json(
        _MARINE_URL,
        {
            "latitude": lat,
            "longitude": lng,
            "current": _MARINE_CURRENT,
            "hourly": _MARINE_HOURLY,
            "forecast_hours": _FORECAST_HOURS,
            "timezone": "auto",
        },
    )
    forecast_task = _get_json(
        _FORECAST_URL,
        {
            "latitude": lat,
            "longitude": lng,
            "current": _FORECAST_CURRENT,
            "hourly": _FORECAST_HOURLY,
            "forecast_hours": _FORECAST_HOURS,
            "timezone": "auto",
            "wind_speed_unit": "kmh",
        },
    )

    marine, forecast = await asyncio.gather(marine_task, forecast_task)

    if marine is None or forecast is None:
        return None

    return _merge(marine, forecast)


async def _get_json(url: str, params: dict[str, Any]) -> dict[str, Any] | None:
    assert _client is not None
    try:
        resp = await _client.get(url, params=params)
    except httpx.HTTPError as exc:
        log.warning("open-meteo request failed for %s: %s", url, exc)
        return None

    if resp.status_code != 200:
        log.info("open-meteo non-200 for %s: %s", url, resp.status_code)
        return None

    try:
        payload = resp.json()
    except ValueError:
        log.warning("open-meteo non-JSON response for %s", url)
        return None

    return payload if isinstance(payload, dict) else None


def _merge(marine: dict[str, Any], forecast: dict[str, Any]) -> dict[str, Any] | None:
    m_hourly = marine.get("hourly") or {}
    f_hourly = forecast.get("hourly") or {}

    m_times: list[str] = m_hourly.get("time") or []
    f_times: list[str] = f_hourly.get("time") or []

    wave_heights = m_hourly.get("wave_height") or []
    if not wave_heights or all(v is None for v in wave_heights):
        return None

    f_time_index = {t: i for i, t in enumerate(f_times)}

    hourly: list[dict[str, Any]] = []
    for i, t in enumerate(m_times):
        wh = _at(wave_heights, i)
        if wh is None:
            continue
        fj = f_time_index.get(t)
        hourly.append(
            {
                "timestamp": t,
                "wave_height_m": wh,
                "wave_period_s": _at(m_hourly.get("wave_period"), i),
                "swell_direction_deg": _at(m_hourly.get("swell_wave_direction"), i),
                "wind_speed_kmh": _at(f_hourly.get("wind_speed_10m"), fj),
                "wind_direction_deg": _at(f_hourly.get("wind_direction_10m"), fj),
                "precipitation_mm": _at(f_hourly.get("precipitation"), fj),
                "weather_code": _coerce_int(_at(f_hourly.get("weather_code"), fj)),
            }
        )

    m_current = marine.get("current") or {}
    f_current = forecast.get("current") or {}
    current = {
        "timestamp": m_current.get("time") or f_current.get("time") or "",
        "air_temp_c": f_current.get("temperature_2m"),
        "water_temp_c": m_current.get("sea_surface_temperature"),
        "wave_height_m": m_current.get("wave_height"),
        "wave_period_s": m_current.get("wave_period"),
        "wave_direction_deg": m_current.get("wave_direction"),
        "wind_speed_kmh": f_current.get("wind_speed_10m"),
        "wind_gust_kmh": f_current.get("wind_gusts_10m"),
        "wind_direction_deg": f_current.get("wind_direction_10m"),
        "weather_code": _coerce_int(f_current.get("weather_code")),
    }

    if not current["timestamp"]:
        current["timestamp"] = datetime.now(timezone.utc).isoformat()

    return {"conditions": current, "hourly": hourly}


def _at(seq: list[Any] | None, idx: int | None) -> Any:
    if seq is None or idx is None or idx < 0 or idx >= len(seq):
        return None
    return seq[idx]


def _coerce_int(v: Any) -> int | None:
    if v is None:
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        return None
