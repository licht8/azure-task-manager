from datetime import datetime, timezone

from database.connection import get_database_connection

from schemas.task_schema import (
    TaskCreate,
    TaskUpdate
)


def get_placeholder():
    """
    Return the SQL parameter placeholder
    depending on the database driver.
    """

    connection = get_database_connection()

    try:
        if connection.__class__.__module__.startswith("psycopg"):
            return "%s"

        return "?"

    finally:
        connection.close()


def create_task(task: TaskCreate):

    connection = get_database_connection()

    created_at = datetime.now(
        timezone.utc
    )

    placeholder = (
        "%s"
        if connection.__class__.__module__.startswith("psycopg")
        else "?"
    )

    query = f"""
        INSERT INTO tasks (
            title,
            description,
            status,
            priority,
            due_date,
            created_at
        )
        VALUES (
            {placeholder},
            {placeholder},
            {placeholder},
            {placeholder},
            {placeholder},
            {placeholder}
        )
    """

    if connection.__class__.__module__.startswith("psycopg"):

        query += " RETURNING id"

        cursor = connection.execute(
            query,
            (
                task.title,
                task.description,
                task.status.value,
                task.priority.value,
                task.due_date,
                created_at
            )
        )

        task_id = cursor.fetchone()["id"]

    else:

        cursor = connection.execute(
            query,
            (
                task.title,
                task.description,
                task.status.value,
                task.priority.value,
                task.due_date.isoformat()
                if task.due_date
                else None,
                created_at.isoformat()
            )
        )

        task_id = cursor.lastrowid

    connection.commit()
    connection.close()

    return {
        "id": task_id,
        "title": task.title,
        "description": task.description,
        "status": task.status,
        "priority": task.priority,
        "due_date": task.due_date,
        "created_at": created_at
    }


def get_all_tasks(
    status=None,
    priority=None,
    search=None,
    skip=0,
    limit=10
):

    connection = get_database_connection()

    placeholder = (
        "%s"
        if connection.__class__.__module__.startswith("psycopg")
        else "?"
    )

    query = """
        SELECT
            id,
            title,
            description,
            status,
            priority,
            due_date,
            created_at
        FROM tasks
    """

    conditions = []
    parameters = []

    if status is not None:

        conditions.append(
            f"status = {placeholder}"
        )

        parameters.append(
            status.value
        )

    if priority is not None:

        conditions.append(
            f"priority = {placeholder}"
        )

        parameters.append(
            priority.value
        )

    if search is not None:

        conditions.append(
            f"(title LIKE {placeholder} OR description LIKE {placeholder})"
        )

        search_pattern = f"%{search}%"

        parameters.extend([
            search_pattern,
            search_pattern
        ])

    if conditions:

        query += (
            " WHERE "
            + " AND ".join(conditions)
        )

    query += f"""
        ORDER BY id DESC
        LIMIT {placeholder}
        OFFSET {placeholder}
    """

    parameters.extend([
        limit,
        skip
    ])

    tasks = connection.execute(
        query,
        parameters
    ).fetchall()

    connection.close()

    return [
        dict(task)
        for task in tasks
    ]


def get_task(task_id: int):

    connection = get_database_connection()

    placeholder = (
        "%s"
        if connection.__class__.__module__.startswith("psycopg")
        else "?"
    )

    task = connection.execute(
        f"""
        SELECT
            id,
            title,
            description,
            status,
            priority,
            due_date,
            created_at
        FROM tasks
        WHERE id = {placeholder}
        """,
        (task_id,)
    ).fetchone()

    connection.close()

    if task is None:
        return None

    return dict(task)


def update_task(
    task_id: int,
    task: TaskUpdate
):

    connection = get_database_connection()

    placeholder = (
        "%s"
        if connection.__class__.__module__.startswith("psycopg")
        else "?"
    )

    existing_task = connection.execute(
        f"""
        SELECT *
        FROM tasks
        WHERE id = {placeholder}
        """,
        (task_id,)
    ).fetchone()

    if existing_task is None:

        connection.close()

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

    connection.execute(
        f"""
        UPDATE tasks
        SET
            title = {placeholder},
            description = {placeholder},
            status = {placeholder},
            priority = {placeholder},
            due_date = {placeholder}
        WHERE id = {placeholder}
        """,
        (
            new_title,
            new_description,
            new_status,
            new_priority,
            new_due_date,
            task_id
        )
    )

    connection.commit()

    updated_task = connection.execute(
        f"""
        SELECT
            id,
            title,
            description,
            status,
            priority,
            due_date,
            created_at
        FROM tasks
        WHERE id = {placeholder}
        """,
        (task_id,)
    ).fetchone()

    connection.close()

    return dict(updated_task)


def delete_task(task_id: int):

    connection = get_database_connection()

    placeholder = (
        "%s"
        if connection.__class__.__module__.startswith("psycopg")
        else "?"
    )

    cursor = connection.execute(
        f"""
        DELETE FROM tasks
        WHERE id = {placeholder}
        """,
        (task_id,)
    )

    connection.commit()

    deleted = cursor.rowcount > 0

    connection.close()

    return deleted


def get_task_stats():

    connection = get_database_connection()

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
        """
    ).fetchone()

    connection.close()

    return dict(stats)