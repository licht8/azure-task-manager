from datetime import datetime, timezone


def log_activity(
    connection,
    user_id: int,
    action: str,
    description: str,
    task_id: int | None = None
):
    """
    Create an activity record using the existing database connection.
    """

    created_at = datetime.now(timezone.utc)

    connection.execute(
        """
        INSERT INTO activity (
            user_id,
            task_id,
            action,
            description,
            created_at
        )
        VALUES (
            %s,
            %s,
            %s,
            %s,
            %s
        )
        """,
        (
            user_id,
            task_id,
            action,
            description,
            created_at
        )
    )


def get_user_activity(
    user_id: int,
    limit: int = 20
):
    """
    Return recent activity only for the authenticated user.
    """

    from database.connection import get_database_connection

    connection = get_database_connection()

    try:

        activities = connection.execute(
            """
            SELECT
                id,
                task_id,
                action,
                description,
                created_at
            FROM activity
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (
                user_id,
                limit
            )
        ).fetchall()

        return [
            dict(activity)
            for activity in activities
        ]

    finally:

        connection.close()