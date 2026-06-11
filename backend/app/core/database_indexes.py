import logging
from pathlib import Path
from sqlalchemy import text
from app.core.database import engine

logger = logging.getLogger(__name__)

INDEX_SQL_PATH = Path(__file__).resolve().parents[2] / "db_indexes.sql"


def _load_index_statements(sql_text: str) -> list[str]:
    """Return executable SQL statements, ignoring line comments."""
    uncommented_sql = "\n".join(
        line for line in sql_text.splitlines() if not line.strip().startswith("--")
    )
    return [
        statement.strip()
        for statement in uncommented_sql.split(";")
        if statement.strip()
    ]


async def ensure_database_indexes() -> None:
    """Create or verify production-ready PostgreSQL indexes."""
    sql_text = INDEX_SQL_PATH.read_text(encoding="utf-8")

    if not sql_text.strip():
        logger.warning("No index SQL found in %s", INDEX_SQL_PATH)
        return

    async with engine.begin() as conn:
        for statement in _load_index_statements(sql_text):
            await conn.execute(text(statement))

    logger.info("PostgreSQL performance indexes ensured successfully")
