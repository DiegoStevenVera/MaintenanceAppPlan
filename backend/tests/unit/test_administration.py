import pytest
from pydantic import ValidationError

import app.models  # noqa: F401
from app.database import Base
from modules.administration.interfaces.schemas import UserWriteRequest


def test_people_administration_columns_are_registered() -> None:
    users = Base.metadata.tables["users"]

    assert "job_title" in users.columns
    assert "appears_in_schedule" in users.columns
    assert "work_area_schedule_viewers" in Base.metadata.tables


def test_user_creation_requires_controlled_role_and_valid_password() -> None:
    with pytest.raises(ValidationError):
        UserWriteRequest(
            name="Test User",
            email="test@example.com",
            role="UNCONTROLLED_ROLE",
            job_title="Tecnico",
            password="12345678",
        )

    with pytest.raises(ValidationError):
        UserWriteRequest(
            name="Test User",
            email="test@example.com",
            role="MAINTENANCE_ENGINEER",
            job_title="Tecnico",
            password="short",
        )
