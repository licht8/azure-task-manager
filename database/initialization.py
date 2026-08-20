from database.connection import get_database_connection


def initialize_database():

    connection = get_database_connection()

    try:

        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username TEXT NOT NULL UNIQUE,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMP NOT NULL
            )
            """
        )
        
        connection.execute(
            """
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS avatar TEXT NOT NULL DEFAULT 'avatar-01'
            """
        )

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

        connection.execute(
            """
            ALTER TABLE tasks
            ADD COLUMN IF NOT EXISTS user_id INTEGER
            REFERENCES users(id)
            ON DELETE CASCADE
            """
        )
        
        
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS projects (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                user_id INTEGER NOT NULL
                    REFERENCES users(id)
                    ON DELETE CASCADE,
                created_at TIMESTAMP NOT NULL
            )
            """
        )

        connection.execute(
            """
            ALTER TABLE tasks
            ADD COLUMN IF NOT EXISTS project_id INTEGER
                REFERENCES projects(id)
                ON DELETE SET NULL
            """
        )

        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS activity (
                id SERIAL PRIMARY KEY,

                user_id INTEGER NOT NULL
                REFERENCES users(id)
                ON DELETE CASCADE,

                task_id INTEGER NULL,

                action TEXT NOT NULL,

                description TEXT NOT NULL,

                created_at TIMESTAMP NOT NULL
            )
            """
        )

        # Remove the old foreign key from activity.task_id.
        # Activity records must keep the task ID even after
        # the corresponding task has been deleted.
        connection.execute(
            """
            ALTER TABLE activity
            DROP CONSTRAINT IF EXISTS activity_task_id_fkey
            """
        )

        connection.commit()

    finally:

        connection.close()