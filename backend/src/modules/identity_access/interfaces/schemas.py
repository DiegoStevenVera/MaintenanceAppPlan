from pydantic import BaseModel

from shared_kernel.schemas import UserRole


class UserDTO(BaseModel):
    id: str
    name: str
    email: str
    role: UserRole
    role_label: str


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenPairDTO(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserDTO
