from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm

from schemas.auth_schema import (
    UserCreate,
    UserResponse,
    UserLogin,
    TokenResponse,
    ChangePasswordRequest
)

from services.auth_service import (
    create_user,
    authenticate_user,
    change_password
)

from core.security import (
    create_access_token,
    get_current_user
)


router = APIRouter()


@router.post(
    "/auth/register",
    response_model=UserResponse,
    tags=["Authentication"],
    summary="Register User"
)
def register_user(user: UserCreate):

    created_user = create_user(user)

    if created_user is None:

        raise HTTPException(
            status_code=409,
            detail="Username or email already exists"
        )

    return created_user


@router.post(
    "/auth/login",
    response_model=TokenResponse,
    tags=["Authentication"],
    summary="Login"
)
def login_user(
    form_data: OAuth2PasswordRequestForm = Depends()
):

    authenticated_user = authenticate_user(
        form_data.username,
        form_data.password
    )

    if authenticated_user is None:

        raise HTTPException(
            status_code=401,
            detail="Invalid username or password"
        )

    token = create_access_token(
        authenticated_user["id"]
    )

    return {
        "access_token": token,
        "token_type": "bearer"
    }


@router.get(
    "/auth/me",
    response_model=UserResponse,
    tags=["Authentication"],
    summary="Get Current User"
)
def get_me(
    current_user: dict = Depends(get_current_user)
):

    return current_user


@router.post(
    "/auth/change-password",
    tags=["Authentication"],
    summary="Change Password"
)
def change_user_password(
    password_data: ChangePasswordRequest,
    current_user: dict = Depends(get_current_user)
):

    changed = change_password(
        current_user["id"],
        password_data.current_password,
        password_data.new_password
    )

    if not changed:

        raise HTTPException(
            status_code=400,
            detail="Current password is incorrect"
        )

    return {
        "message": "Password changed successfully"
    }