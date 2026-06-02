from pydantic import BaseModel, Field


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


class TideExtreme(BaseModel):
    timestamp: str
    type: str
    sea_level_height_m: float | None = None


class TideCurrent(BaseModel):
    timestamp: str
    sea_level_height_m: float | None = None
    state: str = "unknown"
    next_extreme: TideExtreme | None = None


class TideSample(BaseModel):
    timestamp: str
    sea_level_height_m: float | None = None
    state: str = "unknown"


class TideInfo(BaseModel):
    current: TideCurrent | None = None
    timeline: list[TideSample] = Field(default_factory=list)


class ForecastSlot(BaseModel):
    start_timestamp: str
    end_timestamp: str
    part_of_day: str
    wave_height_m: float | None = None
    wave_period_s: float | None = None
    swell_direction_deg: float | None = None
    wind_speed_kmh: float | None = None
    wind_direction_deg: float | None = None
    precipitation_mm: float | None = None
    weather_code: int | None = None
    tide_state: str = "unknown"
    score: int
    verdict: str


class BestWindow(BaseModel):
    part_of_day: str
    start_timestamp: str
    end_timestamp: str
    score: int
    verdict: str
    summary: str


class SpotConditionsResponse(BaseModel):
    spot_id: str
    fetched_at: str
    conditions: CurrentConditions | None = None
    hourly: list[HourlySlot] = Field(default_factory=list)
    tide: TideInfo | None = None
    forecast_slots: list[ForecastSlot] = Field(default_factory=list)
    best_windows: list[BestWindow] = Field(default_factory=list)
    error: str | None = None
