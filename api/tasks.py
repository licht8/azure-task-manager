from fastapi import APIRouter, HTTPException, Query

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
    tags=["Tasks"]
)
def create_task_endpoint(task: TaskCreate):
    return create_task(task)


@router.get(
    "/tasks",
    response_model=list[TaskResponse],
    tags=["Tasks"],
    summary="List Tasks",
    description="List tasks with optional filtering, search and pagination."
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
    )
):
    return get_all_tasks(
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
    description="Return statistics about tasks."
)
def get_task_stats_endpoint():

    return get_task_stats()

@router.get(
    "/tasks/{task_id}",
    response_model=TaskResponse,
    tags=["Tasks"]
)
def get_task_endpoint(task_id: int):

    task = get_task(task_id)

    if task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return task


@router.put(
    "/tasks/{task_id}",
    response_model=TaskResponse,
    tags=["Tasks"]
)
def update_task_endpoint(
    task_id: int,
    task: TaskUpdate
):

    updated_task = update_task(
        task_id,
        task
    )

    if updated_task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return updated_task


@router.delete(
    "/tasks/{task_id}",
    tags=["Tasks"]
)
def delete_task_endpoint(task_id: int):

    deleted = delete_task(task_id)

    if not deleted:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return {
        "message": "Task deleted",
        "id": task_id
    }