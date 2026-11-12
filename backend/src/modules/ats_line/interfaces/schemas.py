from pydantic import BaseModel, Field


class ATSLineDistanceRequest(BaseModel):
    origin_segment_id: str = Field(min_length=1, max_length=80)
    origin_x: float = Field(ge=0)
    destination_segment_id: str = Field(min_length=1, max_length=80)
    destination_x: float = Field(ge=0)
