from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from db.client import get_pool
from schemas.conditions import SpotConditionsResponse
from schemas.spots import SearchResponse
from services import open_meteo_service
from services.geocoding_service import geocode_place
from services.search_service import get_spot_by_id, search_by_geo, search_by_text

router = APIRouter(tags=["spots"])


@router.get("/spots/search", response_model=SearchResponse)
async def search_spots(
    q: str | None = Query(default=None, min_length=1, max_length=100),
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius: int = Query(default=30000, ge=1, le=200000),
    geocode_radius: int = Query(default=50000, ge=1, le=200000),
    limit: int = Query(default=10, ge=1, le=50),
    pool=Depends(get_pool),
) -> SearchResponse:
    text_mode = q is not None
    geo_mode = lat is not None and lng is not None

    if text_mode and geo_mode:
        raise HTTPException(400, "provide either q or lat+lng, not both")
    if not text_mode and not geo_mode:
        raise HTTPException(400, "provide q or lat+lng")
    if geo_mode and (lat is None or lng is None):
        raise HTTPException(400, "lat and lng must both be provided")

    if text_mode:
        spots = await search_by_text(pool, q, limit)
        if not spots:
            coords = await geocode_place(q)
            if coords is not None:
                lat_g, lng_g = coords
                spots = await search_by_geo(pool, lat_g, lng_g, geocode_radius, limit)
    else:
        spots = await search_by_geo(pool, lat, lng, radius, limit)

    return SearchResponse(spots=spots)


@router.get("/spots/{spot_id}/conditions", response_model=SpotConditionsResponse)
async def get_spot_conditions(
    spot_id: str,
    pool=Depends(get_pool),
) -> SpotConditionsResponse:
    spot = await get_spot_by_id(pool, spot_id)
    if spot is None:
        raise HTTPException(404, "Spot not found")

    fetched_at = datetime.now(timezone.utc).isoformat()

    data = await open_meteo_service.fetch_conditions(spot["lat"], spot["lng"])
    if data is None:
        return SpotConditionsResponse(
            spot_id=spot_id,
            fetched_at=fetched_at,
            conditions=None,
            hourly=[],
            error="No marine data available for this location",
        )

    return SpotConditionsResponse(
        spot_id=spot_id,
        fetched_at=fetched_at,
        conditions=data["conditions"],
        hourly=data["hourly"],
    )
