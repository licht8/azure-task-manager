from database.connection import get_database_connection


def get_analytics(
    user_id: int
):
    """
    Return analytics and recent activity
    for the authenticated user.
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
                            WHEN due_date < NOW()
                            AND status != 'completed'
                            THEN 1
                            ELSE 0
                        END
                    ),
                    0
                ) AS overdue,

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


        activity = connection.execute(
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

            LIMIT 20
            """,
            (user_id,)
        ).fetchall()


        return {
            "statistics": dict(stats),

            "activity": [
                dict(item)
                for item in activity
            ]
        }

    finally:

        connection.close()