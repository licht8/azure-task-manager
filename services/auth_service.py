from datetime import datetime, timezone

from database.connection import get_database_connection

from core.security import (
    hash_password,
    verify_password
)

from schemas.auth_schema import UserCreate


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
                created_at
            )
        )

        user_id = cursor.fetchone()["id"]

        connection.commit()

        return {
            "id": user_id,
            "username": user.username,
            "email": user.email,
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