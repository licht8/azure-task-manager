from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class TaskStatus(str, Enum):
    pending = "pending"
    in_progress = "in_progress"
    completed = "completed"


class TaskPriority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class TaskCreate(BaseModel):

    title: str = Field(
        ...,
        min_length=1,
        max_length=200,
        description="Task title"
    )

    description: str | None = Field(
        default=None,
        max_length=1000,
        description="Optional task description"
    )

    status: TaskStatus = Field(
        default=TaskStatus.pending,
        description="Task status"
    )

    priority: TaskPriority = Field(
        default=TaskPriority.medium,
        description="Task priority"
    )

    due_date: datetime | None = Field(
        default=None,
        description="Optional task deadline"
    )


class TaskUpdate(BaseModel):

    title: str | None = Field(
        default=None,
        min_length=1,
        max_length=200,
        description="Updated task title"
    )

    description: str | None = Field(
        default=None,
        max_length=1000,
        description="Updated task description"
    )

    status: TaskStatus | None = Field(
        default=None,
        description="Updated task status"
    )

    priority: TaskPriority | None = Field(
        default=None,
        description="Updated task priority"
    )

    due_date: datetime | None = Field(
        default=None,
        description="Updated task deadline"
    )


class TaskResponse(BaseModel):

    id: int
    title: str
    description: str | None

    status: TaskStatus
    priority: TaskPriority

    due_date: datetime | None

    created_at: datetime
    
class TaskStatsResponse(BaseModel):

    total: int
    pending: int
    in_progress: int
    completed: int

    low_priority: int
    medium_priority: int
    high_priority: int