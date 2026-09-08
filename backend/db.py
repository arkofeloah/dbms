"""
db.py — MySQL connection handler for food_waste_db.
Reads all config from .env via python-dotenv.
Provides get_connection() — callers are responsible for
closing the connection (use as a context manager or call .close()).
"""
import os
import mysql.connector
from dotenv import load_dotenv

# Load variables from backend/.env (the file sits next to this module)
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))


def get_connection():
    """Return a new mysql.connector connection to the database."""
    conn_params = {
        "host": os.environ["DB_HOST"],
        "port": int(os.environ.get("DB_PORT", 3306)),
        "user": os.environ["DB_USER"],
        "password": os.environ["DB_PASSWORD"],
        "database": os.environ["DB_NAME"],
        "autocommit": False,          # we manage transactions explicitly
        "charset": "utf8mb4",
        "use_pure": True,             # pure-Python driver (no C extension required)
        "ssl_disabled": os.environ.get("DB_SSL_DISABLED", "false").lower() in ("true", "1"),
    }

    if os.environ.get("DB_SSL_CA"):
        conn_params["ssl_ca"] = os.environ["DB_SSL_CA"]
    if os.environ.get("DB_SSL_CERT"):
        conn_params["ssl_cert"] = os.environ["DB_SSL_CERT"]
    if os.environ.get("DB_SSL_KEY"):
        conn_params["ssl_key"] = os.environ["DB_SSL_KEY"]

    return mysql.connector.connect(**conn_params)
