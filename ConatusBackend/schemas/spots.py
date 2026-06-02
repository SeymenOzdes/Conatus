from typing import Literal

from pydantic import BaseModel


SearchMatchType = Literal["text", "geo", "geocode", "nearest"]


class SpotResult(BaseModel):
    spot_id: str
    name: str
    lat: float
    lng: float
    break_type: str | None = None
    country: str | None = None
    region: str | None = None
    distance_m: int | None = None
    nearest_only: bool | None = None


class SearchResponse(BaseModel):
    spots: list[SpotResult]
    match_type: SearchMatchType | None = None
