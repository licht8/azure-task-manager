from datetime import datetime

from pydantic import BaseModel, Field


class ProjectCreate(BaseModel):

    name: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Project name"
    )

    description: str | None = Field(
        default=None,
        max_length=1000,
        description="Optional project description"
    )


class ProjectUpdate(BaseModel):

    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=100,
        description="Updated project name"
    )

    description: str | None = Field(
        default=None,
        max_length=1000,
        description="Updated project description"
    )


class ProjectResponse(BaseModel):

    id: int

    name: str

    description: str | None

    created_at: datetime