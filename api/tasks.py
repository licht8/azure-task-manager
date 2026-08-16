from fastapi import APIRouter, Depends, HTTPException, Query

from core.security import get_current_user

from schemas.task_schema import (
    TaskCreate,
    TaskUpdate,
    TaskResponse,
    TaskStatus,
    TaskPriority,
    TaskStatsResponse
)

from services.task_service import (
    create_task,
    get_all_tasks,
    get_task,
    update_task,
    delete_task,
    get_task_stats
)


router = APIRouter()


@router.post(
    "/tasks",
    response_model=TaskResponse,
    tags=["Tasks"],
    summary="Create Task",
    description="Create a new task for the authenticated user."
)
def create_task_endpoint(
    task: TaskCreate,
    current_user: dict = Depends(get_current_user)
):
    return create_task(
        task,
        current_user["id"]
    )


@router.get(
    "/tasks",
    response_model=list[TaskResponse],
    tags=["Tasks"],
    summary="List Tasks",
    description="List only tasks belonging to the authenticated user."
)
def get_tasks_endpoint(
    status: TaskStatus | None = Query(
        default=None,
        description="Filter tasks by status"
    ),
    priority: TaskPriority | None = Query(
        default=None,
        description="Filter tasks by priority"
    ),
    search: str | None = Query(
        default=None,
        min_length=1,
        description="Search in task title and description"
    ),
    skip: int = Query(
        default=0,
        ge=0,
        description="Number of tasks to skip"
    ),
    limit: int = Query(
        default=10,
        ge=1,
        le=100,
        description="Maximum number of tasks to return"
    ),
    current_user: dict = Depends(get_current_user)
):
    return get_all_tasks(
        user_id=current_user["id"],
        status=status,
        priority=priority,
        search=search,
        skip=skip,
        limit=limit
    )


@router.get(
    "/tasks/stats",
    response_model=TaskStatsResponse,
    tags=["Tasks"],
    summary="Task Statistics",
    description="Return statistics for the authenticated user's tasks."
)
def get_task_stats_endpoint(
    current_user: dict = Depends(get_current_user)
):

    return get_task_stats(
        user_id=current_user["id"]
    )


@router.get(
    "/tasks/{task_id}",
    response_model=TaskResponse,
    tags=["Tasks"],
    summary="Get Task",
    description="Get a task belonging to the authenticated user."
)
def get_task_endpoint(
    task_id: int,
    current_user: dict = Depends(get_current_user)
):

    task = get_task(
        task_id,
        current_user["id"]
    )

    if task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return task


@router.put(
    "/tasks/{task_id}",
    response_model=TaskResponse,
    tags=["Tasks"],
    summary="Update Task",
    description="Update a task belonging to the authenticated user."
)
def update_task_endpoint(
    task_id: int,
    task: TaskUpdate,
    current_user: dict = Depends(get_current_user)
):

    updated_task = update_task(
        task_id,
        task,
        current_user["id"]
    )

    if updated_task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return updated_task


@router.delete(
    "/tasks/{task_id}",
    tags=["Tasks"],
    summary="Delete Task",
    description="Delete a task belonging to the authenticated user."
)
def delete_task_endpoint(
    task_id: int,
    current_user: dict = Depends(get_current_user)
):

    deleted = delete_task(
        task_id,
        current_user["id"]
    )

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return {
        "message": "Task deleted",
        "id": task_id
    }