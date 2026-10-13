"""Load the curated catalog (catalog.json) into the assets table. Idempotent.

Usage (from backend/):  .venv/bin/python -m app.market_data.seed
"""

import asyncio
import json
from pathlib import Path
from typing import Any

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Asset

CATALOG_PATH = Path(__file__).with_name("catalog.json")


def load_catalog() -> list[dict[str, Any]]:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


async def seed_catalog(session: AsyncSession) -> tuple[int, int]:
    """Insert new catalog entries, refresh existing ones. Returns (created, updated)."""
    entries = load_catalog()
    existing = {
        (a.provider, a.provider_symbol): a for a in (await session.execute(select(Asset))).scalars()
    }
    # Assets dropped from the curated list stay searchable but are no longer "popular".
    await session.execute(update(Asset).values(popularity=None))
    created = updated = 0
    for entry in entries:
        asset = existing.get((entry["provider"], entry["provider_symbol"]))
        if asset is None:
            session.add(Asset(**entry, is_active=True))
            created += 1
        else:
            for field, value in entry.items():
                setattr(asset, field, value)
            asset.is_active = True
            updated += 1
    await session.commit()
    return created, updated


async def _main() -> None:
    from app.db.session import SessionLocal, engine

    async with SessionLocal() as session:
        created, updated = await seed_catalog(session)
    await engine.dispose()
    print(f"Catalog seeded: {created} created, {updated} updated.")


if __name__ == "__main__":
    asyncio.run(_main())
