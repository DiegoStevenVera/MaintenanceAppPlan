from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.config import settings
from modules.ats_line.infrastructure.repository import ATSLineRepository
from modules.ats_line.interfaces.schemas import ATSLineDistanceRequest
from modules.identity_access.interfaces.dependencies import get_current_user


router = APIRouter(
    prefix="/ats-line",
    tags=["ats-line"],
    dependencies=[Depends(get_current_user)],
)


def _repository() -> ATSLineRepository:
    try:
        return ATSLineRepository(settings.resolved_ats_line_data)
    except (FileNotFoundError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error


@router.get("")
def get_line() -> dict[str, Any]:
    return _repository().line_payload()


@router.get("/objects/{object_id}")
def get_line_object(object_id: str) -> dict[str, Any]:
    return _repository().object_detail(object_id)


@router.post("/distance")
def calculate_line_distance(payload: ATSLineDistanceRequest) -> dict[str, Any]:
    try:
        return _repository().distance_between(
            payload.origin_segment_id,
            payload.origin_x,
            payload.destination_segment_id,
            payload.destination_x,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(error),
        ) from error
