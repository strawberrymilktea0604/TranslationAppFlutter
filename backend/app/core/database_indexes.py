import logging
from pathlib import Path
from sqlalchemy import text
from app.core.database import engine

logger = logging.getLogger(__name__)

INDEX_SQL_PATH = Path(__file__).resolve().parent.parent / "db_indexes.sql"


async def ensure_database_indexes() -> None:
    """Create or verify production-ready PostgreSQL indexes."""
    sql_text = INDEX_SQL_PATH.read_text(encoding="utf-8")

    if not sql_text.strip():
        logger.warning("No index SQL found in %s", INDEX_SQL_PATH)
        return

    async with engine.begin() as conn:
        for statement in sql_text.split(";"):
            statement = statement.strip()
            if not statement:
                continue
            await conn.execute(text(statement))

    logger.info("PostgreSQL performance indexes ensured successfully")
