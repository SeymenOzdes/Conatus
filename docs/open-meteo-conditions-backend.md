# Open-Meteo Marine Conditions — Backend

**Endpoint:** `GET /v1/spots/{spot_id}/conditions`

## Genel Bakış

Bir sörf spotu için Open-Meteo'dan anlık + 24 saatlik tahmin (dalga, swell, rüzgar, yağış, hava durumu kodu) çeker. API anahtarı gerektirmez.

---

## Yeni / Değişen Dosyalar

### `ConatusBackend/schemas/conditions.py` _(yeni)_
Pydantic response şeması:

| Model | Alanlar |
|---|---|
| `CurrentConditions` | `timestamp`, `air_temp_c`, `water_temp_c`, `wave_height_m`, `wave_period_s`, `wave_direction_deg`, `wind_speed_kmh`, `wind_gust_kmh`, `wind_direction_deg`, `weather_code` |
| `HourlySlot` | `timestamp`, `wave_height_m`, `wave_period_s`, `swell_direction_deg`, `wind_speed_kmh`, `wind_direction_deg`, `precipitation_mm`, `weather_code` |
| `SpotConditionsResponse` | `spot_id`, `fetched_at`, `conditions`, `hourly[]`, `error` |

---

### `ConatusBackend/services/open_meteo_service.py` _(yeni)_

`geocoding_service.py` ile aynı kalıp: modül-seviyesi global'ler + lifespan yönetimi.

**Sabitler:**
```
_MARINE_URL   = https://marine-api.open-meteo.com/v1/marine
_FORECAST_URL = https://api.open-meteo.com/v1/forecast
_HTTP_TIMEOUT_S = 5.0
_CACHE_TTL_S    = 1800  (30 dk)
_FORECAST_HOURS = 24
```

**Cache:** `(round(lat,3), round(lng,3))` çiftini anahtar olarak kullanır (~110 m hücre). `asyncio.Lock` ile eş zamanlı özdeş istekler tek upstream çağrısına indirilir.

**Upstream çağrılar:** `asyncio.gather` ile Marine + Forecast API paralel çağrılır.

**Inland / kapsama dışı:** Marine API 4xx döndürürse veya `wave_height` dizisi tamamen `null`sa → `None` döner → endpoint `conditions: null, error: "No marine data available for this location"` ile 200 yanıt verir.

---

### `ConatusBackend/services/search_service.py` _(değişti)_

Yeni yardımcı fonksiyon eklendi:

```python
async def get_spot_by_id(pool, spot_id: str) -> dict | None
```
`surf_spots_v2` tablosundan `id, name, lat, lng, region` döner; bulunamazsa `None`.

---

### `ConatusBackend/routers/spots.py` _(değişti)_

Yeni route:

```
GET /v1/spots/{spot_id}/conditions
```

| Durum | HTTP | Yanıt |
|---|---|---|
| Spot bulunamadı | 404 | `{ "detail": "Spot not found" }` |
| Kıyı dışı / kapsama yok | 200 | `{ "conditions": null, "error": "No marine data available for this location", "hourly": [] }` |
| Başarılı | 200 | Tam `SpotConditionsResponse` |

---

### `ConatusBackend/main.py` _(değişti)_

Lifespan'e `open_meteo_service.startup()` / `shutdown()` eklendi (geocoding_service'ten sonra başlar, ondan önce kapanır).

---

## Yerel Test

```bash
# 1. Sunucu başlat
cd ConatusBackend
unset VIRTUAL_ENV
uv run uvicorn main:app --reload --port 8000

# 2. Spot ID al
curl "http://localhost:8000/v1/spots/search?q=Pipeline&limit=1" | jq '.spots[0].spot_id'

# 3. Koşulları sorgula
curl "http://localhost:8000/v1/spots/<spot_id>/conditions" | jq

# 4. Inland testi (Ankara koordinatları)
curl "http://localhost:8000/v1/spots/test-inland-id/conditions" | jq
# → { "conditions": null, "error": "No marine data available for this location" }
```
