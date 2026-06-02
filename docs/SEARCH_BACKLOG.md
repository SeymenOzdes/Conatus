# Conatus — Search & Backend Backlog

Status snapshot (2026-05-13):
- ✅ Text search on `surf_spots_v2` (tsvector + ILIKE)
- ✅ Geo proximity search via PostGIS (`ST_DWithin`)
- ✅ City-name fallback via Nominatim with in-process TTL cache
- ✅ `/v1/spots/{id}/conditions` (Open-Meteo marine data)
- ✅ iOS `SpotSearchViewModel` debounced → `SearchSuggestionsView`

What's still missing, grouped by impact.

---

## P1 — User-visible gaps

### iOS: distance label on geocode-fallback results
**Where:** `Conatus/Views/Component/SearchBar/SearchSuggestionsView.swift`
**What:** `SpotResult.distance_m` is decoded but never rendered. When a city query triggers the geocode fallback, results carry distance in metres but the suggestion row only shows `country · break_type`. Show e.g. `· 4.6 km` next to the row when `distance_m != nil` (and `nil` for direct text matches so the UI stays clean).
**Why:** without this, users searching "San Diego" see five rows in an arbitrary-looking order with no signal that they're sorted by proximity.

### iOS: "Searching near {city}" header
**Where:** `SearchSuggestionsView` + `SpotSearchState`
**What:** when results came from geocoding (heuristic: all rows have `distance_m`), show a small header row "Spots near {query}". Backend currently gives no explicit signal — easiest path is to infer from `distance_m` being set on every row. A cleaner contract would be a `match_type: "text" | "geo"` field on the response.
**Why:** disambiguates "no spot named San Diego, but here are nearby ones" from "we found a spot literally called San Diego".

### Backend: nearest-spot fallback when city found but no spots in radius
**Where:** `routers/spots.py` text-mode branch, after the geocode call.
**What:** the spec calls for "City found but no surf spots within radius → return empty array with nearest spot suggestion". Today the response is just `{"spots": []}`. Implement: when 50 km radius yields 0 rows, run one more PostGIS query without the radius cap and return the single nearest spot. Mark it with a `nearest_only: true` flag (new field) so the UI can render it as "Nearest spot — 240 km away".
**Why:** queries like "Paris" or "Madrid" geocode successfully but the city centroid is too far from any coast; users get a dead-end empty state.

### Backend: empty-input / whitespace guard for geocoding
**Where:** `services/geocoding_service.py:geocode_place`
**What:** add a min-length guard (e.g. skip the Nominatim call if `len(normalized) < 3`). Today a 1-2 char `q` that misses the DB triggers an outbound HTTP call on every keystroke during fast typing.
**Why:** debounce + Nominatim's 1 req/s policy means a user typing "biarritz" can fire 4-5 outbound requests in succession.

---

## P2 — Robustness

### Backend: structured logging
**Where:** new `db/logging.py` or inline in services.
**What:** stop using `logging.basicConfig` defaults. Add a JSON formatter, include `request_id` per request (middleware), and log a single line per `/spots/search` with `q`, `n_text_hits`, `geocoded`, `n_geo_hits`, `cache_hit`, `duration_ms`.
**Why:** without this we can't see geocode hit rate or fallback frequency in production.

### Backend: persistent geocode cache (Redis)
**Where:** `services/geocoding_service.py`
**What:** swap the module-level dict for Redis with the same 30-day positive / 1-hour negative TTLs. Wire a connection pool in `lifespan`. Required before going multi-instance.
**Why:** the in-process cache is wiped on every restart and doesn't share across workers (uvicorn `--workers > 1`).

### Backend: integration tests for search endpoint
**Where:** new `tests/test_spots_search.py`
**What:** pytest + httpx.AsyncClient against an ephemeral Postgres container (testcontainers or docker-compose fixture). Cover: (a) text match, (b) geocode fallback hit, (c) geocode 404, (d) `q` + `lat/lng` mutual-exclusion 400, (e) cache hit on identical consecutive queries.
**Why:** the fallback chain is the kind of multi-branch logic that silently rots when individual queries change.

### Backend: rate-limit `/v1/spots/search`
**Where:** new middleware or `slowapi`.
**What:** 30 req/min per IP. The geocode fallback chains out to Nominatim — a malicious or buggy client could violate Nominatim's usage policy and get the whole app's IP banned.
**Why:** Nominatim explicitly bans abusers; the policy is "absolute maximum of 1 request per second, with no other clients sharing it".

### Backend: duplicate city-name disambiguation
**Where:** `services/geocoding_service.py` (request additional Nominatim fields), `schemas/spots.py` (new response field).
**What:** Nominatim with `limit=1` arbitrarily picks Newport, RI over Newport, Wales. Bump `limit=3`, surface a `disambiguation: [{display_name, lat, lng}, …]` in the response, let the UI ask the user "Did you mean…?" when multiple cities tie.
**Why:** known footgun in the original spec; today we silently pick the OSM ranking winner.

---

## P3 — Polish / future

### Backend: rename `country` ↔ `region` mismatch
**Where:** `schemas/spots.py`, `services/search_service.py`
**What:** the DB column is `region` and contains a hierarchical label ("USA, California, San Mateo") — not a country. The API field is named `country`. Either rename the API field to `region` (breaks iOS) or split into `country` + `region` columns when re-ingesting `newSurfSpots.json`.
**Why:** iOS code reads `country` and shows "USA, California, San Mateo" in the subtitle — works, but the naming is misleading and will trip up future devs.

### Backend: unify ETL on asyncpg
**Where:** `load_new_surf_spots.py`, `fetch_surf_spots.py`
**What:** ETL scripts use sync `psycopg2`; the API uses `asyncpg`. Two driver stacks, two connection idioms. Migrate the loaders to asyncpg or keep psycopg2 only for the ETL and document the split.
**Why:** cosmetic but every new contributor asks why both exist.

### Backend: surface match_type in response
**Where:** `schemas/spots.py:SearchResponse`
**What:** add `match_type: Literal["text", "geo"] | None` so iOS doesn't have to infer from `distance_m`. Optional — only needed if we add the "Searching near X" UI.

### iOS: cancel in-flight search on result tap
**Where:** `SpotSearchViewModel`
**What:** when the user taps a suggestion, cancel any pending debounced search. Today a fast tap-then-keep-typing can race the selection with a newer query.

### Dev: kill stale uvicorn on boot
**Where:** dev-only helper script or Makefile target.
**What:** `make backend` should `lsof -ti :8000 | xargs kill -9` then start uvicorn. Earlier in this project we had two uvicorns competing for port 8000; documenting/scripting this would have saved an hour.

---

## Out of scope (parked)

- Search-as-you-type analytics / dwell tracking
- Multi-language queries (Nominatim handles many languages already; not a blocker)
- Personalized ranking by user's recent location
