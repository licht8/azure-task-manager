from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pwdlib import PasswordHash

from database.connection import get_database_connection


# ============================================================
# Password hashing
# ============================================================

password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """
    Hash a plain-text password using a secure password hashing
    algorithm.
    """

    return password_hash.hash(password)


def verify_password(
    password: str,
    password_hash_value: str
) -> bool:
    """
    Verify a plain-text password against its stored hash.
    """

    return password_hash.verify(
        password,
        password_hash_value
    )


# ============================================================
# JWT configuration
# ============================================================

JWT_SECRET_KEY = "change-this-secret-key"

JWT_ALGORITHM = "HS256"

JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 60


oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/login"
)


# ============================================================
# JWT token creation
# ============================================================

def create_access_token(user_id: int) -> str:
    """
    Create a JWT access token containing the user's ID.
    """

    expire = datetime.now(
        timezone.utc
    ) + timedelta(
        minutes=JWT_ACCESS_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": str(user_id),
        "exp": expire
    }

    return jwt.encode(
        payload,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM
    )


# ============================================================
# Current authenticated user
# ============================================================

def get_current_user(
    token: str = Depends(oauth2_scheme)
):
    """
    Validate the JWT token and return the current user.
    """

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication token",
        headers={
            "WWW-Authenticate": "Bearer"
        }
    )

    try:

        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM]
        )

        user_id = payload.get("sub")

        if user_id is None:
            raise credentials_exception

        user_id = int(user_id)

    except (
        jwt.InvalidTokenError,
        ValueError,
        TypeError
    ):

        raise credentials_exception

    connection = get_database_connection()

    try:

        user = connection.execute(
            """
            SELECT
                id,
                username,
                email,
                created_at
            FROM users
            WHERE id = %s
            """,
            (user_id,)
        ).fetchone()

    finally:

        connection.close()

    if user is None:
        raise credentials_exception

    return dict(user)