from datetime import datetime, timezone

from database.connection import get_database_connection

from schemas.project_schema import (
    ProjectCreate,
    ProjectUpdate
)


def create_project(
    user_id: int,
    project: ProjectCreate
):
    connection = get_database_connection()

    try:

        existing_project = connection.execute(
            """
            SELECT id
            FROM projects
            WHERE user_id = %s
              AND name = %s
            """,
            (
                user_id,
                project.name
            )
        ).fetchone()

        if existing_project:
            return None

        created_at = datetime.now(timezone.utc)

        project_row = connection.execute(
            """
            INSERT INTO projects (
                user_id,
                name,
                description,
                created_at
            )
            VALUES (
                %s,
                %s,
                %s,
                %s
            )
            RETURNING
                id,
                name,
                description,
                created_at
            """,
            (
                user_id,
                project.name,
                project.description,
                created_at
            )
        ).fetchone()

        connection.commit()

        return dict(project_row)

    finally:
        connection.close()


def get_projects(user_id: int):

    connection = get_database_connection()

    try:

        projects = connection.execute(
            """
            SELECT
                id,
                name,
                description,
                created_at
            FROM projects
            WHERE user_id = %s
            ORDER BY created_at DESC
            """,
            (user_id,)
        ).fetchall()

        return [
            dict(project)
            for project in projects
        ]

    finally:
        connection.close()


def get_project_by_id(
    user_id: int,
    project_id: int
):

    connection = get_database_connection()

    try:

        project = connection.execute(
            """
            SELECT
                id,
                name,
                description,
                created_at
            FROM projects
            WHERE id = %s
              AND user_id = %s
            """,
            (
                project_id,
                user_id
            )
        ).fetchone()

        if project is None:
            return None

        return dict(project)

    finally:
        connection.close()


def update_project(
    user_id: int,
    project_id: int,
    project: ProjectUpdate
):

    connection = get_database_connection()

    try:

        existing_project = connection.execute(
            """
            SELECT id
            FROM projects
            WHERE user_id = %s
              AND name = %s
              AND id != %s
            """,
            (
                user_id,
                project.name,
                project_id
            )
        ).fetchone()

        if existing_project:
            return None

        updated_project = connection.execute(
            """
            UPDATE projects
            SET
                name = %s,
                description = %s
            WHERE id = %s
              AND user_id = %s
            RETURNING
                id,
                name,
                description,
                created_at
            """,
            (
                project.name,
                project.description,
                project_id,
                user_id
            )
        ).fetchone()

        if updated_project is None:
            return None

        connection.commit()

        return dict(updated_project)

    finally:
        connection.close()


def delete_project(
    user_id: int,
    project_id: int
):

    connection = get_database_connection()

    try:

        deleted_project = connection.execute(
            """
            DELETE FROM projects
            WHERE id = %s
              AND user_id = %s
            RETURNING id
            """,
            (
                project_id,
                user_id
            )
        ).fetchone()

        if deleted_project is None:
            return False

        connection.commit()

        return True

    finally:
        connection.close()
        

def project_belongs_to_user(
    user_id: int,
    project_id: int
):
    connection = get_database_connection()

    try:

        project = connection.execute(
            """
            SELECT id
            FROM projects
            WHERE id = %s
            AND user_id = %s
            """,
            (
                project_id,
                user_id
            )
        ).fetchone()

        return project is not None

    finally:

        connection.close()