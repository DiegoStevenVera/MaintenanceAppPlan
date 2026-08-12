import pytest

from modules.identity_access.application.security import (
    InvalidTokenError,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from modules.identity_access.interfaces.schemas import UserDTO
from shared_kernel.schemas import UserRole


def test_argon2_password_round_trip() -> None:
    password_hash = hash_password("a-secure-password")

    assert password_hash.startswith("$argon2")
    assert verify_password(password_hash, "a-secure-password") == (True, None)
    assert verify_password(password_hash, "wrong") == (False, None)


def test_legacy_mock_password_requests_argon2_upgrade() -> None:
    valid, replacement = verify_password("mock:123456", "123456")

    assert valid is True
    assert replacement is not None
    assert replacement.startswith("$argon2")


def test_access_token_contains_authenticated_identity() -> None:
    user = UserDTO(
        id="user-test",
        name="Test User",
        email="test@example.com",
        role=UserRole.COORDINATOR,
        role_label="Coordinador",
    )

    token, _ = create_access_token(user)
    claims = decode_token(token, expected_type="access")

    assert claims.subject == user.id
    assert claims.role == UserRole.COORDINATOR


def test_refresh_token_cannot_be_used_as_access_token() -> None:
    user = UserDTO(
        id="user-test",
        name="Test User",
        email="test@example.com",
        role=UserRole.COORDINATOR,
        role_label="Coordinador",
    )
    refresh_token, _ = create_refresh_token(user, "session-test")

    with pytest.raises(InvalidTokenError):
        decode_token(refresh_token, expected_type="access")
