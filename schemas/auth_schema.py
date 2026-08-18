from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):

    username: str = Field(
        ...,
        min_length=3,
        max_length=50,
        description="Username"
    )

    email: EmailStr

    password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description="User password"
    )


class UserLogin(BaseModel):

    username: str = Field(
        ...,
        min_length=1,
        description="Username"
    )

    password: str = Field(
        ...,
        min_length=1,
        description="User password"
    )


class UserResponse(BaseModel):

    id: int
    username: str
    email: str
    avatar: str
    created_at: datetime


class TokenResponse(BaseModel):

    access_token: str
    token_type: str


class ChangePasswordRequest(BaseModel):

    current_password: str = Field(
        ...,
        min_length=1,
        description="Current password"
    )

    new_password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description="New password"
    )
    
    
class UpdateProfileRequest(BaseModel):
    username: str = Field(
        ...,
        min_length=3,
        max_length=50,
        description="Username"
    )

    avatar: str = Field(
        ...,
        pattern=r"^avatar-(0[1-9]|10)$",
        description="Selected avatar"
    )