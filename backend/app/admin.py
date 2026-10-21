"""Admin commands for the dev/prod server (run from backend/):

    .venv/bin/python -m app.admin grant-pro someone@example.com --days 30
    .venv/bin/python -m app.admin grant-pro someone@example.com --forever
    .venv/bin/python -m app.admin revoke-pro someone@example.com
    .venv/bin/python -m app.admin pro-interest        # who asked to hear about Pro

Payments come at launch; until then Pro is granted by hand to testers.
"""

import argparse
import asyncio
import sys

from sqlalchemy import func, select

from app.db.models import User
from app.db.session import SessionLocal, engine
from app.services import plans


async def _user(session, email: str) -> User:
    user = (
        await session.execute(select(User).where(func.lower(User.email) == email.lower()))
    ).scalar_one_or_none()
    if user is None:
        sys.exit(f"No account with the email {email}.")
    return user


async def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="python -m app.admin")
    commands = parser.add_subparsers(dest="command", required=True)
    grant = commands.add_parser("grant-pro", help="give a tester Pro")
    grant.add_argument("email")
    length = grant.add_mutually_exclusive_group()
    length.add_argument("--days", type=int, default=30)
    length.add_argument("--forever", action="store_true")
    revoke = commands.add_parser("revoke-pro", help="end a tester's Pro now")
    revoke.add_argument("email")
    commands.add_parser("pro-interest", help="list who asked to hear when Pro is ready")
    args = parser.parse_args(argv)

    try:
        async with SessionLocal() as session:
            if args.command == "grant-pro":
                user = await _user(session, args.email)
                days = None if args.forever else args.days
                granted = await plans.grant_pro(session, user, days)
                until = (
                    "until revoked" if granted.ends_at is None else f"until {granted.ends_at} UTC"
                )
                print(f"{user.email} now has Pro {until}.")
            elif args.command == "revoke-pro":
                user = await _user(session, args.email)
                ended = await plans.revoke_pro(session, user)
                print(f"Ended {ended} Pro grant(s) for {user.email}.")
            else:
                rows = await plans.pro_interest(session)
                for email, name, when in rows:
                    print(f"{when:%Y-%m-%d %H:%M}  {email}  {name}")
                print(f"{len(rows)} people asked to hear when Pro is ready.")
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
