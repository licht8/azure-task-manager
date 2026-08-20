from fastapi import APIRouter, Depends, HTTPException, status

from schemas.project_schema import (
    ProjectCreate,
    ProjectUpdate,
    ProjectResponse
)

from services.project_service import (
    create_project,
    get_projects,
    get_project_by_id,
    update_project,
    delete_project
)

from core.security import get_current_user


router = APIRouter(
    prefix="/projects",
    tags=["Projects"]
)


@router.post(
    "",
    response_model=ProjectResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Project"
)
def create_project_endpoint(
    project: ProjectCreate,
    current_user: dict = Depends(get_current_user)
):
    created_project = create_project(
        current_user["id"],
        project
    )

    if created_project is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Project with this name already exists"
        )

    return created_project


@router.get(
    "",
    response_model=list[ProjectResponse],
    summary="Get User Projects"
)
def get_projects_endpoint(
    current_user: dict = Depends(get_current_user)
):
    return get_projects(
        current_user["id"]
    )


@router.get(
    "/{project_id}",
    response_model=ProjectResponse,
    summary="Get Project"
)
def get_project_endpoint(
    project_id: int,
    current_user: dict = Depends(get_current_user)
):
    project = get_project_by_id(
        current_user["id"],
        project_id
    )

    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found"
        )

    return project


@router.put(
    "/{project_id}",
    response_model=ProjectResponse,
    summary="Update Project"
)
def update_project_endpoint(
    project_id: int,
    project: ProjectUpdate,
    current_user: dict = Depends(get_current_user)
):
    updated_project = update_project(
        current_user["id"],
        project_id,
        project
    )

    if updated_project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found"
        )

    return updated_project


@router.delete(
    "/{project_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete Project"
)
def delete_project_endpoint(
    project_id: int,
    current_user: dict = Depends(get_current_user)
):
    deleted = delete_project(
        current_user["id"],
        project_id
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found"
        )

    return None