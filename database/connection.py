import os
import sqlite3

import psycopg
from psycopg.rows import dict_row


DATABASE_URL = os.getenv("DATABASE_URL")


def get_database_connection():

    if DATABASE_URL:

        connection = psycopg.connect(
            DATABASE_URL,
            row_factory=dict_row
        )

        return connection

    os.makedirs(
        "data",
        exist_ok=True
    )

    connection = sqlite3.connect(
        "data/tasks.db"
    )

    connection.row_factory = sqlite3.Row

    return connection