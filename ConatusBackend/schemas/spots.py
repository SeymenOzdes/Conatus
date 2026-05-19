from pydantic import BaseModel


class SpotResult(BaseModel):
    spot_id: str
    name: str
    lat: float
    lng: float
    break_type: str | None = None
    country: str | None = None
    distance_m: int | None = None


class SearchResponse(BaseModel):
    spots: list[SpotResult]
