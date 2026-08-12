from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from uuid import uuid4

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from app.config import settings
from modules.identity_access.interfaces.schemas import UserDTO

_password_hasher = PasswordHasher()


class InvalidTokenError(Exception):
    pass


@dataclass(frozen=True)
class TokenClaims:
    subject: str
    role: str
    token_type: str
    token_id: str
    session_id: str | None
    expires_at: datetime


def hash_password(password: str) -> str:
    return _password_hasher.hash(password)


def verify_password(password_hash: str, password: str) -> tuple[bool, str | None]:
    if password_hash.startswith("mock:"):
        valid = password_hash == f"mock:{password}"
        return valid, hash_password(password) if valid else None

    if not password_hash.startswith("$argon2"):
        return False, None

    try:
        valid = _password_hasher.verify(password_hash, password)
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return False, None

    replacement = hash_password(password) if _password_hasher.check_needs_rehash(password_hash) else None
    return valid, replacement


def create_access_token(user: UserDTO) -> tuple[str, datetime]:
    expires_at = datetime.now(UTC) + timedelta(minutes=settings.access_token_expire_minutes)
    return _encode_token(
        user=user,
        token_type="access",
        expires_at=expires_at,
        session_id=None,
    ), expires_at


def create_refresh_token(user: UserDTO, session_id: str) -> tuple[str, datetime]:
    expires_at = datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days)
    return _encode_token(
        user=user,
        token_type="refresh",
        expires_at=expires_at,
        session_id=session_id,
    ), expires_at


def decode_token(token: str, expected_type: str) -> TokenClaims:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=["HS256"],
            issuer=settings.jwt_issuer,
            options={"require": ["exp", "iat", "iss", "jti", "sub", "type"]},
        )
    except jwt.PyJWTError as error:
        raise InvalidTokenError from error

    if payload.get("type") != expected_type:
        raise InvalidTokenError

    try:
        return TokenClaims(
            subject=str(payload["sub"]),
            role=str(payload["role"]),
            token_type=str(payload["type"]),
            token_id=str(payload["jti"]),
            session_id=str(payload["sid"]) if payload.get("sid") else None,
            expires_at=datetime.fromtimestamp(int(payload["exp"]), tz=UTC),
        )
    except (KeyError, TypeError, ValueError) as error:
        raise InvalidTokenError from error


def token_digest(token: str) -> str:
    return sha256(token.encode("utf-8")).hexdigest()


def new_session_id() -> str:
    return str(uuid4())


def _encode_token(
    *,
    user: UserDTO,
    token_type: str,
    expires_at: datetime,
    session_id: str | None,
) -> str:
    now = datetime.now(UTC)
    payload: dict[str, str | datetime] = {
        "sub": user.id,
        "role": user.role.value,
        "type": token_type,
        "jti": str(uuid4()),
        "iss": settings.jwt_issuer,
        "iat": now,
        "exp": expires_at,
    }
    if session_id is not None:
        payload["sid"] = session_id
    return jwt.encode(payload, settings.jwt_secret_key, algorithm="HS256")
