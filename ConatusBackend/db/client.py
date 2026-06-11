import os
import logging

import asyncpg

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/surfapp",
)
DATABASE_REQUIRED = os.environ.get("CONATUS_REQUIRE_DATABASE", "").lower() in {
    "1",
    "true",
    "yes",
}

_pool: asyncpg.Pool | None = None
log = logging.getLogger(__name__)


async def init_pool() -> asyncpg.Pool | None:
    global _pool
    if _pool is None:
        try:
            _pool = await asyncpg.create_pool(
                DATABASE_URL,
                min_size=1,
                max_size=10,
            )
        except (OSError, asyncpg.PostgresError) as exc:
            if DATABASE_REQUIRED:
                raise

            safe_url = DATABASE_URL.split("@")[-1]
            log.warning(
                "PostgreSQL is unavailable at %s; DB-backed routes will return 503. "
                "Set CONATUS_REQUIRE_DATABASE=1 to fail startup instead. Error: %s",
                safe_url,
                exc,
            )
    return _pool


async def close_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None


def get_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError(
            "Database is unavailable. Start PostgreSQL or set DATABASE_URL to a reachable database."
        )
    return _pool


def is_pool_ready() -> bool:
    return _pool is not None
