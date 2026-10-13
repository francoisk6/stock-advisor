from sqlalchemy import case, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Asset
from app.market_data.types import FoundAsset


async def get(session: AsyncSession, asset_id: int) -> Asset | None:
    asset = await session.get(Asset, asset_id)
    return asset if asset is not None and asset.is_active else None


async def search_local(session: AsyncSession, query: str, limit: int) -> list[Asset]:
    q = query.strip()
    pattern = f"%{q}%"
    result = await session.execute(
        select(Asset)
        .where(
            Asset.is_active.is_(True),
            or_(Asset.symbol.like(f"{q}%"), Asset.name.like(pattern)),
        )
        .order_by(
            # Exact symbol first (the column collation is case-insensitive).
            case((Asset.symbol == q, 0), else_=1),
            Asset.popularity.is_(None),  # curated assets before ones added from searches
            Asset.popularity,
            Asset.name,
        )
        .limit(limit)
    )
    return list(result.scalars())


async def popular(
    session: AsyncSession, asset_types: list[str], regions: list[str] | None
) -> list[Asset]:
    stmt = select(Asset).where(
        Asset.is_active.is_(True),
        Asset.popularity.is_not(None),
        Asset.asset_type.in_(asset_types),
    )
    if regions is not None:
        stmt = stmt.where(Asset.region.in_([*regions, "global"]))
    result = await session.execute(stmt.order_by(Asset.popularity, Asset.id))
    return list(result.scalars())


async def upsert_found(session: AsyncSession, found: list[FoundAsset]) -> list[Asset]:
    """Store provider search hits in the catalog (so they get ids); returns them in order."""
    if not found:
        return []
    keys = {(f.provider, f.provider_symbol) for f in found}
    existing = {
        (a.provider, a.provider_symbol): a
        for a in (
            await session.execute(
                select(Asset).where(
                    Asset.provider_symbol.in_([k[1] for k in keys]),
                    Asset.provider.in_({k[0] for k in keys}),
                )
            )
        ).scalars()
    }
    assets = []
    for f in found:
        asset = existing.get((f.provider, f.provider_symbol))
        if asset is None:
            asset = Asset(
                symbol=f.symbol[:32],
                name=f.name[:200],
                asset_type=f.asset_type.value,
                exchange=(f.exchange or None) and f.exchange[:100],
                country=f.country,
                region=f.region,
                currency=f.currency,
                provider=f.provider,
                provider_symbol=f.provider_symbol,
                logo_url=f.logo_url,
                is_active=True,
            )
            session.add(asset)
            existing[(f.provider, f.provider_symbol)] = asset
        assets.append(asset)
    await session.commit()
    return assets
