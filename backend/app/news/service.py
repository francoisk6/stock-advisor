"""News per asset: fetched on demand (at most every 30 min per asset), stored, deduplicated."""

import hashlib
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.time import utcnow
from app.db.models import Asset, NewsArticle, NewsArticleAsset
from app.market_data.cache import TTLCache
from app.market_data.types import ProviderError
from app.news.google_news import GoogleNews, NewsItem, news_query

provider = GoogleNews()
fetched = TTLCache(stale_for=0)  # remembers when each asset's news was last refreshed
REFRESH_SECONDS = 30 * 60
MAX_AGE = timedelta(days=7)
KEEP_PER_FETCH = 15


def url_hash(url: str) -> str:
    return hashlib.sha256(url.encode()).hexdigest()


async def store(session: AsyncSession, asset: Asset, items: list[NewsItem]) -> int:
    """Insert new articles and link them to the asset; returns how many links were added."""
    items = sorted(items, key=lambda i: i.published_at, reverse=True)[:KEEP_PER_FETCH]
    if not items:
        return 0
    hashes = {url_hash(i.url): i for i in items}
    existing = {
        a.url_hash: a
        for a in (
            await session.execute(select(NewsArticle).where(NewsArticle.url_hash.in_(list(hashes))))
        ).scalars()
    }
    articles = []
    for h, item in hashes.items():
        article = existing.get(h)
        if article is None:
            article = NewsArticle(
                url_hash=h,
                url=item.url,
                title=item.title,
                source=item.source,
                published_at=item.published_at,
                provider=provider.name,
                fetched_at=utcnow(),
            )
            session.add(article)
        articles.append(article)
    await session.flush()
    linked = set(
        (
            await session.execute(
                select(NewsArticleAsset.article_id).where(
                    NewsArticleAsset.asset_id == asset.id,
                    NewsArticleAsset.article_id.in_([a.id for a in articles]),
                )
            )
        ).scalars()
    )
    added = 0
    for article in articles:
        if article.id not in linked:
            session.add(NewsArticleAsset(article_id=article.id, asset_id=asset.id))
            added += 1
    await session.commit()
    return added


async def refresh(session: AsyncSession, asset: Asset) -> None:
    """Fetch fresh headlines unless this asset was refreshed recently. Never raises."""
    key = f"news:{asset.id}"
    if fetched.peek(key, REFRESH_SECONDS) is not None:
        return
    try:
        items = await provider.search(news_query(asset))
    except ProviderError:
        return  # stored headlines are still shown
    await store(session, asset, items)
    fetched.put(key, True)


async def latest(session: AsyncSession, asset: Asset, limit: int = 10) -> list[NewsArticle]:
    result = await session.execute(
        select(NewsArticle)
        .join(NewsArticleAsset, NewsArticleAsset.article_id == NewsArticle.id)
        .where(
            NewsArticleAsset.asset_id == asset.id,
            NewsArticle.published_at >= utcnow() - MAX_AGE,
        )
        .order_by(NewsArticle.published_at.desc())
        .limit(limit)
    )
    return list(result.scalars())


async def news_for(session: AsyncSession, asset: Asset, limit: int = 10) -> list[NewsArticle]:
    await refresh(session, asset)
    return await latest(session, asset, limit)
