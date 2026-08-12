import argparse
import asyncio
from getpass import getpass

from sqlalchemy import select

from app.database import async_session_factory
from modules.identity_access.application.security import hash_password
from modules.identity_access.infrastructure.postgres.models import UserRecord


async def set_password(email: str, password: str) -> None:
    if len(password) < 8:
        raise ValueError("The password must contain at least 8 characters")

    async with async_session_factory() as session:
        user = await session.scalar(
            select(UserRecord).where(UserRecord.email.ilike(email.strip()))
        )
        if user is None:
            raise LookupError(f"User not found: {email}")
        user.password_hash = hash_password(password)
        user.is_active = True
        await session.commit()
        print(f"Password updated for {user.email}")


async def bootstrap_disabled_users(password: str) -> None:
    if len(password) < 8:
        raise ValueError("The password must contain at least 8 characters")

    async with async_session_factory() as session:
        users = (
            await session.scalars(
                select(UserRecord).where(
                    UserRecord.password_hash == "!legacy-import-disabled!"
                )
            )
        ).all()
        for user in users:
            user.password_hash = hash_password(password)
            user.is_active = True
        await session.commit()
        print(f"Bootstrapped {len(users)} imported users")


def main() -> None:
    parser = argparse.ArgumentParser(description="MaintenanceApp user administration")
    subparsers = parser.add_subparsers(dest="command", required=True)

    set_password_parser = subparsers.add_parser("set-password")
    set_password_parser.add_argument("--email", required=True)

    subparsers.add_parser("bootstrap-disabled")
    args = parser.parse_args()

    password = getpass("New temporary password: ")
    confirmation = getpass("Repeat password: ")
    if password != confirmation:
        raise ValueError("Passwords do not match")

    if args.command == "set-password":
        asyncio.run(set_password(args.email, password))
    else:
        asyncio.run(bootstrap_disabled_users(password))


if __name__ == "__main__":
    main()
