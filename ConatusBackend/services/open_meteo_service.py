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
endpoint surfaces { "conditions": null, "error": "..." }. Forecast weather
data is best-effort; marine data is enough to render the spot.
"""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

log = logging.getLogger(__name__)

_MARINE_URL = "https://marine-api.open-meteo.com/v1/marine"
_FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
_METNO_URL = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
_USER_AGENT = "Conatus/0.1 (ozdesxseymen@gmail.com)"
_HTTP_TIMEOUT_S = 5.0
_CACHE_TTL_S = 30 * 60
_FORECAST_HOURS = 24

_MARINE_HOURLY = (
    "wave_height,wave_period,wave_direction,"
    "swell_wave_height,swell_wave_period,swell_wave_direction,"
    "sea_surface_temperature,sea_level_height_msl"
)
_MARINE_CURRENT = (
    "wave_height,wave_period,wave_direction,"
    "sea_surface_temperature,sea_level_height_msl"
)

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
            "cell_selection": "sea",
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

    if marine is None:
        return None
    if forecast is None:
        forecast = await _fetch_metno_forecast(lat, lng)

    return _merge(marine, forecast)


async def _get_json(url: str, params: dict[str, Any]) -> dict[str, Any] | None:
    assert _client is not None
    try:
        resp = await _client.get(url, params=params)
    except httpx.HTTPError as exc:
        log.warning(
            "open-meteo request failed for %s: %s: %r",
            url,
            type(exc).__name__,
            exc,
        )
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


async def _fetch_metno_forecast(lat: float, lng: float) -> dict[str, Any] | None:
    payload = await _get_json(
        _METNO_URL,
        {
            "lat": lat,
            "lon": lng,
        },
    )
    if payload is None:
        return None

    timeseries = ((payload.get("properties") or {}).get("timeseries") or [])
    if not isinstance(timeseries, list) or not timeseries:
        return None

    hourly_rows: list[dict[str, Any]] = []
    for item in timeseries:
        if not isinstance(item, dict):
            continue
        timestamp = item.get("time")
        data = item.get("data") or {}
        details = ((data.get("instant") or {}).get("details") or {})
        if not timestamp or not details:
            continue

        next_1h = data.get("next_1_hours") or {}
        precipitation = (next_1h.get("details") or {}).get("precipitation_amount")
        symbol = ((next_1h.get("summary") or {}).get("symbol_code"))

        hourly_rows.append(
            {
                "time": _compact_iso_hour(timestamp),
                "temperature_2m": details.get("air_temperature"),
                "precipitation": precipitation,
                "weather_code": _metno_weather_code(symbol, details.get("cloud_area_fraction")),
                "wind_speed_10m": _ms_to_kmh(details.get("wind_speed")),
                "wind_direction_10m": details.get("wind_from_direction"),
            }
        )
        if len(hourly_rows) >= _FORECAST_HOURS:
            break

    if not hourly_rows:
        return None

    current = hourly_rows[0]
    first_winds = [
        row.get("wind_speed_10m")
        for row in hourly_rows[:3]
        if row.get("wind_speed_10m") is not None
    ]
    current_gust = max(first_winds) if first_winds else current.get("wind_speed_10m")

    return {
        "current": {
            "time": current["time"],
            "temperature_2m": current.get("temperature_2m"),
            "weather_code": current.get("weather_code"),
            "wind_speed_10m": current.get("wind_speed_10m"),
            "wind_direction_10m": current.get("wind_direction_10m"),
            "wind_gusts_10m": current_gust,
        },
        "hourly": {
            "time": [row["time"] for row in hourly_rows],
            "temperature_2m": [row.get("temperature_2m") for row in hourly_rows],
            "precipitation": [row.get("precipitation") for row in hourly_rows],
            "weather_code": [row.get("weather_code") for row in hourly_rows],
            "wind_speed_10m": [row.get("wind_speed_10m") for row in hourly_rows],
            "wind_direction_10m": [row.get("wind_direction_10m") for row in hourly_rows],
        },
    }


def _merge(marine: dict[str, Any], forecast: dict[str, Any] | None) -> dict[str, Any] | None:
    m_hourly = marine.get("hourly") or {}
    f_hourly = (forecast or {}).get("hourly") or {}

    m_times: list[str] = m_hourly.get("time") or []
    wave_heights = m_hourly.get("wave_height") or []
    if not wave_heights or all(v is None for v in wave_heights):
        return None

    hourly = _merge_hourly(m_hourly, f_hourly)
    tide = _build_tide(marine.get("current") or {}, m_hourly)
    forecast_slots = _build_forecast_slots(hourly, tide)
    best_windows = _build_best_windows(forecast_slots)

    m_current = marine.get("current") or {}
    f_current = (forecast or {}).get("current") or {}
    current = _merge_current(m_current, f_current)

    if not current["timestamp"]:
        current["timestamp"] = datetime.now(timezone.utc).isoformat()

    return {
        "conditions": current,
        "hourly": hourly,
        "tide": tide,
        "forecast_slots": forecast_slots,
        "best_windows": best_windows,
    }


def _merge_hourly(m_hourly: dict[str, Any], f_hourly: dict[str, Any]) -> list[dict[str, Any]]:
    m_times: list[str] = m_hourly.get("time") or []
    f_times: list[str] = f_hourly.get("time") or []
    f_time_index = {t: i for i, t in enumerate(f_times)}
    wave_heights = m_hourly.get("wave_height") or []

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
    return hourly


def _merge_current(m_current: dict[str, Any], f_current: dict[str, Any]) -> dict[str, Any]:
    return {
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


def _build_tide(current: dict[str, Any], m_hourly: dict[str, Any]) -> dict[str, Any] | None:
    times: list[str] = m_hourly.get("time") or []
    heights: list[Any] = m_hourly.get("sea_level_height_msl") or []
    samples: list[tuple[str, float | None]] = [
        (t, _coerce_float(_at(heights, i))) for i, t in enumerate(times[:_FORECAST_HOURS])
    ]
    samples = [(t, h) for t, h in samples if h is not None]

    if not samples:
        return None

    values = [h for _, h in samples]
    states = [_tide_state_at(values, i) for i in range(len(values))]

    timeline = [
        {
            "timestamp": timestamp,
            "sea_level_height_m": height,
            "state": states[i],
        }
        for i, (timestamp, height) in enumerate(samples)
    ]

    current_time = current.get("time") or samples[0][0]
    current_height = _coerce_float(current.get("sea_level_height_msl"))
    current_index = _nearest_time_index(samples, current_time)
    if current_height is None:
        current_height = samples[current_index][1]

    state = states[current_index] if 0 <= current_index < len(states) else "unknown"
    next_extreme = _next_tide_extreme(samples, states, current_index)

    return {
        "current": {
            "timestamp": current_time,
            "sea_level_height_m": current_height,
            "state": state,
            "next_extreme": next_extreme,
        },
        "timeline": timeline,
    }


def _build_forecast_slots(
    hourly: list[dict[str, Any]],
    tide: dict[str, Any] | None,
) -> list[dict[str, Any]]:
    tide_by_time = {
        sample["timestamp"]: sample["state"]
        for sample in ((tide or {}).get("timeline") or [])
    }

    slots: list[dict[str, Any]] = []
    for start in range(0, min(len(hourly), _FORECAST_HOURS), 3):
        chunk = hourly[start : start + 3]
        if len(chunk) < 3:
            continue

        start_timestamp = chunk[0]["timestamp"]
        wave_height = _avg([row.get("wave_height_m") for row in chunk])
        wave_period = _avg([row.get("wave_period_s") for row in chunk])
        wind_speed = _avg([row.get("wind_speed_kmh") for row in chunk])
        precipitation = _sum_present([row.get("precipitation_mm") for row in chunk])
        score = _surf_score(wave_height, wave_period, wind_speed, precipitation)

        slots.append(
            {
                "start_timestamp": start_timestamp,
                "end_timestamp": _add_hours_iso(start_timestamp, 3),
                "part_of_day": _part_of_day(start_timestamp),
                "wave_height_m": _round(wave_height, 2),
                "wave_period_s": _round(wave_period, 1),
                "swell_direction_deg": _round(
                    _avg([row.get("swell_direction_deg") for row in chunk]), 0
                ),
                "wind_speed_kmh": _round(wind_speed, 1),
                "wind_direction_deg": _round(
                    _avg([row.get("wind_direction_deg") for row in chunk]), 0
                ),
                "precipitation_mm": _round(precipitation, 1),
                "weather_code": _first_present([row.get("weather_code") for row in chunk]),
                "tide_state": _first_present(
                    [tide_by_time.get(row["timestamp"]) for row in chunk]
                )
                or "unknown",
                "score": score,
                "verdict": _verdict(score),
            }
        )
    return slots


def _build_best_windows(slots: list[dict[str, Any]]) -> list[dict[str, Any]]:
    windows: list[dict[str, Any]] = []
    for part in ("morning", "midday", "evening"):
        candidates = [slot for slot in slots if slot["part_of_day"] == part]
        if not candidates:
            continue
        best = max(candidates, key=lambda slot: slot["score"])
        windows.append(
            {
                "part_of_day": part,
                "start_timestamp": best["start_timestamp"],
                "end_timestamp": best["end_timestamp"],
                "score": best["score"],
                "verdict": best["verdict"],
                "summary": _best_window_summary(best),
            }
        )
    return windows


def _at(seq: list[Any] | None, idx: int | None) -> Any:
    if seq is None or idx is None or idx < 0 or idx >= len(seq):
        return None
    return seq[idx]


def _coerce_float(v: Any) -> float | None:
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _coerce_int(v: Any) -> int | None:
    if v is None:
        return None
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def _tide_state_at(values: list[float], idx: int) -> str:
    current = values[idx]
    prev_value = values[idx - 1] if idx > 0 else None
    next_value = values[idx + 1] if idx + 1 < len(values) else None

    if prev_value is not None and next_value is not None:
        if current >= prev_value and current >= next_value:
            return "high"
        if current <= prev_value and current <= next_value:
            return "low"

    comparison: float
    if prev_value is None and next_value is not None:
        comparison = next_value - current
    elif next_value is None and prev_value is not None:
        comparison = current - prev_value
    elif prev_value is not None and next_value is not None:
        comparison = next_value - prev_value
    else:
        return "unknown"

    if abs(comparison) < 0.02:
        return "steady"
    return "rising" if comparison > 0 else "falling"


def _nearest_time_index(samples: list[tuple[str, float]], timestamp: str) -> int:
    exact = next((i for i, sample in enumerate(samples) if sample[0] == timestamp), None)
    return exact if exact is not None else 0


def _next_tide_extreme(
    samples: list[tuple[str, float]],
    states: list[str],
    start_index: int,
) -> dict[str, Any] | None:
    for i in range(max(0, start_index + 1), len(samples)):
        if states[i] not in {"high", "low"}:
            continue
        timestamp, height = samples[i]
        return {
            "timestamp": timestamp,
            "type": states[i],
            "sea_level_height_m": height,
        }
    return None


def _avg(values: list[Any]) -> float | None:
    present = [_coerce_float(v) for v in values]
    present = [v for v in present if v is not None]
    if not present:
        return None
    return sum(present) / len(present)


def _sum_present(values: list[Any]) -> float | None:
    present = [_coerce_float(v) for v in values]
    present = [v for v in present if v is not None]
    if not present:
        return None
    return sum(present)


def _first_present(values: list[Any]) -> Any:
    return next((v for v in values if v is not None), None)


def _ms_to_kmh(value: Any) -> float | None:
    speed = _coerce_float(value)
    return None if speed is None else round(speed * 3.6, 1)


def _compact_iso_hour(timestamp: str) -> str:
    normalized = timestamp.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized).strftime("%Y-%m-%dT%H:%M")
    except ValueError:
        return timestamp[:16]


def _metno_weather_code(symbol: str | None, cloud_fraction: Any) -> int | None:
    if symbol:
        if "thunder" in symbol:
            return 95
        if "snow" in symbol or "sleet" in symbol:
            return 71
        if "rain" in symbol:
            return 61
        if "fog" in symbol:
            return 45
        if "cloudy" in symbol:
            return 3
        if "fair" in symbol:
            return 1
        if "clearsky" in symbol:
            return 0

    clouds = _coerce_float(cloud_fraction)
    if clouds is None:
        return None
    if clouds < 12.5:
        return 0
    if clouds < 50:
        return 1
    if clouds < 87.5:
        return 2
    return 3


def _round(value: float | None, digits: int) -> float | None:
    return None if value is None else round(value, digits)


def _clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def _surf_score(
    wave_height_m: float | None,
    wave_period_s: float | None,
    wind_speed_kmh: float | None,
    precipitation_mm: float | None,
) -> int:
    avg_wave = wave_height_m or 0.0
    avg_period = wave_period_s or 0.0
    avg_wind = wind_speed_kmh or 0.0
    precipitation = precipitation_mm or 0.0

    height_score = _clamp(avg_wave / 1.5, 0, 1) * 40
    period_score = _clamp((avg_period - 5) / 7, 0, 1) * 30
    wind_score = max(0, 1 - max(avg_wind - 8, 0) / 32) * 25
    weather_score = 5 if precipitation <= 0.5 else 0
    return round(height_score + period_score + wind_score + weather_score)


def _verdict(score: int) -> str:
    if score >= 70:
        return "go"
    if score >= 40:
        return "maybe"
    return "skip"


def _part_of_day(timestamp: str) -> str:
    hour = _parse_hour(timestamp)
    if 5 <= hour < 12:
        return "morning"
    if 12 <= hour < 17:
        return "midday"
    if 17 <= hour < 21:
        return "evening"
    return "night"


def _parse_hour(timestamp: str) -> int:
    try:
        return datetime.fromisoformat(timestamp).hour
    except ValueError:
        return 0


def _add_hours_iso(timestamp: str, hours: int) -> str:
    try:
        return (datetime.fromisoformat(timestamp) + timedelta(hours=hours)).strftime(
            "%Y-%m-%dT%H:%M"
        )
    except ValueError:
        return timestamp


def _best_window_summary(slot: dict[str, Any]) -> str:
    wave = slot.get("wave_height_m")
    period = slot.get("wave_period_s")
    wind = slot.get("wind_speed_kmh")
    tide_state = slot.get("tide_state") or "unknown"
    wave_label = f"{wave:.1f} m" if wave is not None else "unknown waves"
    period_label = f"{period:.0f}s" if period is not None else "unknown period"
    wind_label = f"{wind:.0f} km/h" if wind is not None else "unknown"
    return (
        f"{slot['verdict'].upper()} · "
        f"{wave_label} @ {period_label}, "
        f"{wind_label} wind, {tide_state} tide"
    )
