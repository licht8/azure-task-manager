from datetime import datetime, timezone

from database.connection import get_database_connection

from services.activity_service import log_activity

from schemas.task_schema import (
    TaskCreate,
    TaskUpdate
)


class ProjectNotFoundError(Exception):
    pass


def create_task(
    task: TaskCreate,
    user_id: int
):
    """
    Create a new task for the authenticated user.
    """

    connection = get_database_connection()

    try:

        if task.project_id is not None:

            project = connection.execute(
                """
                SELECT id
                FROM projects
                WHERE id = %s
                AND user_id = %s
                """,
                (
                    task.project_id,
                    user_id
                )
            ).fetchone()

            if project is None:
                raise ProjectNotFoundError()

        created_at = datetime.now(timezone.utc)

        cursor = connection.execute(
            """
            INSERT INTO tasks (
                user_id,
                title,
                description,
                status,
                priority,
                due_date,
                project_id,
                created_at
            )
            VALUES (
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s
            )
            RETURNING id
            """,
            (
                user_id,
                task.title,
                task.description,
                task.status.value,
                task.priority.value,
                task.due_date,
                task.project_id,
                created_at
            )
        )

        task_id = cursor.fetchone()["id"]

        log_activity(
            connection=connection,
            user_id=user_id,
            task_id=task_id,
            action="created",
            description=f'Created task "{task.title}"'
        )

        connection.commit()

        return {
            "id": task_id,
            "title": task.title,
            "description": task.description,
            "status": task.status,
            "priority": task.priority,
            "due_date": task.due_date,
            "project_id": task.project_id,
            "created_at": created_at
        }

    finally:

        connection.close()


def get_all_tasks(
    user_id: int,
    status=None,
    priority=None,
    search=None,
    skip=0,
    limit=10,
    project_id=None
):
    """
    Return only tasks belonging to the authenticated user.
    Optionally filter tasks by project.
    """

    connection = get_database_connection()

    try:

        query = """
            SELECT
                id,
                title,
                description,
                status,
                priority,
                due_date,
                project_id,
                created_at
            FROM tasks
            WHERE user_id = %s
        """

        parameters = [user_id]


        # ====================================================
        # Project filter
        # ====================================================

        if project_id is not None:

            query += """
                AND project_id = %s
            """

            parameters.append(
                project_id
            )


        # ====================================================
        # Status filter
        # ====================================================

        if status is not None:

            query += """
                AND status = %s
            """

            parameters.append(
                status.value
            )


        # ====================================================
        # Priority filter
        # ====================================================

        if priority is not None:

            query += """
                AND priority = %s
            """

            parameters.append(
                priority.value
            )


        # ====================================================
        # Search
        # ====================================================

        if search is not None:

            query += """
                AND (
                    title ILIKE %s
                    OR description ILIKE %s
                )
            """

            search_pattern = f"%{search}%"

            parameters.extend([
                search_pattern,
                search_pattern
            ])


        # ====================================================
        # Pagination
        # ====================================================

        query += """
            ORDER BY id DESC
            LIMIT %s
            OFFSET %s
        """

        parameters.extend([
            limit,
            skip
        ])


        tasks = connection.execute(
            query,
            parameters
        ).fetchall()


        return [
            dict(task)
            for task in tasks
        ]


    finally:

        connection.close()


def get_task(
    task_id: int,
    user_id: int
):
    """
    Return a task only if it belongs to the authenticated user.
    """

    connection = get_database_connection()

    try:

        task = connection.execute(
            """
            SELECT
                id,
                title,
                description,
                status,
                priority,
                due_date,
                project_id,
                created_at
            FROM tasks
            WHERE id = %s
            AND user_id = %s
            """,
            (
                task_id,
                user_id
            )
        ).fetchone()

        if task is None:
            return None

        return dict(task)

    finally:

        connection.close()


def update_task(
    task_id: int,
    task: TaskUpdate,
    user_id: int
):
    """
    Update a task only if it belongs to the authenticated user.
    """

    connection = get_database_connection()

    try:

        existing_task = connection.execute(
            """
            SELECT *
            FROM tasks
            WHERE id = %s
            AND user_id = %s
            """,
            (
                task_id,
                user_id
            )
        ).fetchone()

        if existing_task is None:
            return None

        new_title = (
            task.title
            if task.title is not None
            else existing_task["title"]
        )

        new_description = (
            task.description
            if task.description is not None
            else existing_task["description"]
        )

        new_status = (
            task.status.value
            if task.status is not None
            else existing_task["status"]
        )

        new_priority = (
            task.priority.value
            if task.priority is not None
            else existing_task["priority"]
        )

        new_due_date = (
            task.due_date
            if task.due_date is not None
            else existing_task["due_date"]
        )

        new_project_id = (
            task.project_id
            if task.project_id is not None
            else existing_task["project_id"]
        )

        if new_project_id is not None:

            project = connection.execute(
                """
                SELECT id
                FROM projects
                WHERE id = %s
                AND user_id = %s
                """,
                (
                    new_project_id,
                    user_id
                )
            ).fetchone()

            if project is None:
                raise ProjectNotFoundError()

        connection.execute(
            """
            UPDATE tasks
            SET
                title = %s,
                description = %s,
                status = %s,
                priority = %s,
                due_date = %s,
                project_id = %s
            WHERE id = %s
            AND user_id = %s
            """,
            (
                new_title,
                new_description,
                new_status,
                new_priority,
                new_due_date,
                new_project_id,
                task_id,
                user_id
            )
        )

        log_activity(
            connection=connection,
            user_id=user_id,
            task_id=task_id,
            action="updated",
            description=f"Task '{new_title}' was updated"
        )

        connection.commit()

        updated_task = connection.execute(
            """
            SELECT
                id,
                title,
                description,
                status,
                priority,
                due_date,
                project_id,
                created_at
            FROM tasks
            WHERE id = %s
            AND user_id = %s
            """,
            (
                task_id,
                user_id
            )
        ).fetchone()

        return dict(updated_task)

    finally:

        connection.close()


def delete_task(
    task_id: int,
    user_id: int
):
    """
    Delete a task only if it belongs to the authenticated user.
    """

    connection = get_database_connection()

    try:

        existing_task = connection.execute(
            """
            SELECT
                id,
                title
            FROM tasks
            WHERE id = %s
            AND user_id = %s
            """,
            (
                task_id,
                user_id
            )
        ).fetchone()

        if existing_task is None:
            return False

        log_activity(
            connection=connection,
            user_id=user_id,
            task_id=task_id,
            action="deleted",
            description=f"Task '{existing_task['title']}' was deleted"
        )

        connection.execute(
            """
            DELETE FROM tasks
            WHERE id = %s
            AND user_id = %s
            """,
            (
                task_id,
                user_id
            )
        )

        connection.commit()

        return True

    finally:

        connection.close()


def get_task_stats(
    user_id: int
):
    """
    Return task statistics only for the authenticated user.
    """

    connection = get_database_connection()

    try:

        stats = connection.execute(
            """
            SELECT
                COUNT(*) AS total,

                COALESCE(
                    SUM(
                        CASE
                            WHEN status = 'pending'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS pending,

                COALESCE(
                    SUM(
                        CASE
                            WHEN status = 'in_progress'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS in_progress,

                COALESCE(
                    SUM(
                        CASE
                            WHEN status = 'completed'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS completed,

                COALESCE(
                    SUM(
                        CASE
                            WHEN priority = 'low'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS low_priority,

                COALESCE(
                    SUM(
                        CASE
                            WHEN priority = 'medium'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS medium_priority,

                COALESCE(
                    SUM(
                        CASE
                            WHEN priority = 'high'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS high_priority

            FROM tasks
            WHERE user_id = %s
            """,
            (user_id,)
        ).fetchone()

        return dict(stats)

    finally:

        connection.close()