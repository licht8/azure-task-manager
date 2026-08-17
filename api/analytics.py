from fastapi import APIRouter, Depends

from core.security import get_current_user

from services.analytics_service import get_analytics


router = APIRouter()


@router.get(
    "/analytics",
    tags=["Analytics"],
    summary="Get Analytics",
    description="Return statistics and recent activity for the authenticated user."
)
def get_analytics_endpoint(
    current_user: dict = Depends(get_current_user)
):

    return get_analytics(
        user_id=current_user["id"]
    )