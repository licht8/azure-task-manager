from database.connection import get_database_connection


def initialize_database():

    connection = get_database_connection()

    try:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS tasks (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL DEFAULT 'pending',
                priority TEXT NOT NULL DEFAULT 'medium',
                due_date TIMESTAMP NULL,
                created_at TIMESTAMP NOT NULL
            )
            """
        )

        connection.commit()

    finally:
        connection.close()