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


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class ImpersonateRoleRequest(BaseModel):
    role: UserRole


class RolePreviewOptionDTO(BaseModel):
    role: UserRole
    role_label: str
    user_name: str


class TokenPairDTO(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserDTO
