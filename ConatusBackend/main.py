from contextlib import asynccontextmanager

from fastapi import FastAPI

from db.client import close_pool, init_pool
from routers import spots
from services import geocoding_service, open_meteo_service


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_pool()
    await geocoding_service.startup()
    await open_meteo_service.startup()
    try:
        yield
    finally:
        await open_meteo_service.shutdown()
        await geocoding_service.shutdown()
        await close_pool()


app = FastAPI(title="Conatus Surf API", lifespan=lifespan)
app.include_router(spots.router, prefix="/v1")


@app.get("/healthz")
async def healthz() -> dict:
    return {"ok": True}
