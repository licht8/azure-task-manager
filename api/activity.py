from fastapi import APIRouter, Depends

from core.security import get_current_user
from services.activity_service import get_user_activity


router = APIRouter()


@router.get(
    "/activity",
    tags=["Activity"],
    summary="Get Activity",
    description="Return recent activity for the authenticated user."
)
def get_activity_endpoint(
    current_user: dict = Depends(get_current_user)
):
    return get_user_activity(
        user_id=current_user["id"]
    )