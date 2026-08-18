from datetime import datetime, timezone

from database.connection import get_database_connection

from core.security import (
    hash_password,
    verify_password
)

from schemas.auth_schema import (
    UserCreate,
    UpdateProfileRequest
)


def create_user(user: UserCreate):

    connection = get_database_connection()

    try:

        existing_user = connection.execute(
            """
            SELECT id
            FROM users
            WHERE username = %s
               OR email = %s
            """,
            (
                user.username,
                user.email
            )
        ).fetchone()

        if existing_user:

            return None

        password_hash = hash_password(
            user.password
        )

        created_at = datetime.now(
            timezone.utc
        )

        cursor = connection.execute(
            """
            INSERT INTO users (
                username,
                email,
                password_hash,
                avatar,
                created_at
            )
            VALUES (
                %s,
                %s,
                %s,
                %s
            )
            RETURNING id
            """,
            (
                user.username,
                user.email,
                password_hash,
                "avatar-01",
                created_at
            )
        )

        user_id = cursor.fetchone()["id"]

        connection.commit()

        return {
            "id": user_id,
            "username": user.username,
            "email": user.email,
            "avatar": "avatar-01",
            "created_at": created_at
        }

    finally:

        connection.close()


def authenticate_user(
    username: str,
    password: str
):

    connection = get_database_connection()

    try:

        user = connection.execute(
            """
            SELECT
                id,
                username,
                email,
                password_hash,
                avatar,
                created_at
            FROM users
            WHERE username = %s
            """,
            (username,)
        ).fetchone()

        if user is None:
            return None

        if not verify_password(
            password,
            user["password_hash"]
        ):
            return None

        return dict(user)

    finally:

        connection.close()


def get_user_by_id(user_id: int):

    connection = get_database_connection()

    try:

        user = connection.execute(
            """
            SELECT
                id,
                username,
                email,
                avatar,
                created_at
            FROM users
            WHERE id = %s
            """,
            (user_id,)
        ).fetchone()

        if user is None:
            return None

        return dict(user)

    finally:

        connection.close()
        
        
def update_user_profile(
    user_id: int,
    username: str,
    email: str,
    avatar: str
):
    connection = get_database_connection()

    try:
        existing_user = connection.execute(
            """
            SELECT id
            FROM users
            WHERE (username = %s OR email = %s)
              AND id != %s
            """,
            (
                username,
                email,
                user_id
            )
        ).fetchone()

        if existing_user:
            return None

        user = connection.execute(
            """
            UPDATE users
            SET username = %s,
                email = %s,
                avatar = %s
            WHERE id = %s
            RETURNING id, username, email, avatar, created_at
            """,
            (
                username,
                email,
                avatar,
                user_id
            )
        ).fetchone()

        if user is None:
            return None

        connection.commit()

        return dict(user)

    finally:
        connection.close()
        
        
def change_password(
    user_id: int,
    current_password: str,
    new_password: str
):

    connection = get_database_connection()

    try:

        user = connection.execute(
            """
            SELECT password_hash
            FROM users
            WHERE id = %s
            """,
            (user_id,)
        ).fetchone()

        if user is None:
            return False

        if not verify_password(
            current_password,
            user["password_hash"]
        ):
            return False

        new_password_hash = hash_password(
            new_password
        )

        connection.execute(
            """
            UPDATE users
            SET password_hash = %s
            WHERE id = %s
            """,
            (
                new_password_hash,
                user_id
            )
        )

        connection.commit()

        return True

    finally:

        connection.close()
        
        
def update_profile(
    user_id: int,
    profile_data: UpdateProfileRequest
):
    connection = get_database_connection()

    try:

        existing_user = connection.execute(
            """
            SELECT id
            FROM users
            WHERE username = %s
              AND id != %s
            """,
            (
                profile_data.username,
                user_id
            )
        ).fetchone()

        if existing_user:
            return None

        user = connection.execute(
            """
            UPDATE users
            SET
                username = %s,
                avatar = %s
            WHERE id = %s
            RETURNING
                id,
                username,
                email,
                avatar,
                created_at
            """,
            (
                profile_data.username,
                profile_data.avatar,
                user_id
            )
        ).fetchone()

        if user is None:
            return None

        connection.commit()

        return dict(user)

    finally:

        connection.close()