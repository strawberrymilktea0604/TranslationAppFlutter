from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Engine async từ settings
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=not settings.is_production,  # Không log SQL ở production
    pool_size=20,
    max_overflow=10,
)

async_session_maker = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

async def get_db():
    async with async_session_maker() as session:
        yield session
        await session.close()