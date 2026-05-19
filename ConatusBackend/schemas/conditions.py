from pydantic import BaseModel


class CurrentConditions(BaseModel):
    timestamp: str
    air_temp_c: float | None = None
    water_temp_c: float | None = None
    wave_height_m: float | None = None
    wave_period_s: float | None = None
    wave_direction_deg: float | None = None
    wind_speed_kmh: float | None = None
    wind_gust_kmh: float | None = None
    wind_direction_deg: float | None = None
    weather_code: int | None = None


class HourlySlot(BaseModel):
    timestamp: str
    wave_height_m: float | None = None
    wave_period_s: float | None = None
    swell_direction_deg: float | None = None
    wind_speed_kmh: float | None = None
    wind_direction_deg: float | None = None
    precipitation_mm: float | None = None
    weather_code: int | None = None


class SpotConditionsResponse(BaseModel):
    spot_id: str
    fetched_at: str
    conditions: CurrentConditions | None = None
    hourly: list[HourlySlot] = []
    error: str | None = None
