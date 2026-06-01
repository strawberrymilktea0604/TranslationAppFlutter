import os
import sys
import time
from pathlib import Path

import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from sqlalchemy import BigInteger
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("SECRET_KEY", "test-secret-key-for-backend-tests")

backend_path = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(backend_path))

from app.core.database import get_db  # noqa: E402
from app.core.security import create_access_token, hash_password  # noqa: E402
from app.main import app  # noqa: E402
from app.models.base import Base  # noqa: E402
from app.models.system import ApiMetric  # noqa: E402
from app.models.translation import Translation  # noqa: E402
from app.models.user import User, UserToken  # noqa: E402


@compiles(BigInteger, "sqlite")
def compile_big_integer_for_sqlite(_type, _compiler, **_kw):
    """Use SQLite's rowid-backed INTEGER type for BigInteger primary keys."""
    return "INTEGER"


@pytest_asyncio.fixture
async def db_session():
    """Create an isolated async SQLite session for integration-style tests."""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")

    async with engine.begin() as connection:
        await connection.run_sync(
            lambda sync_connection: Base.metadata.create_all(
                sync_connection,
                tables=[
                    User.__table__,
                    UserToken.__table__,
                    Translation.__table__,
                    ApiMetric.__table__,
                ],
            )
        )

    async_session = sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with async_session() as session:
        yield session

    await engine.dispose()


@pytest.fixture
def client(db_session: AsyncSession, monkeypatch) -> TestClient:
    """Create a test client backed by the isolated async database."""
    async def override_get_db():
        yield db_session

    async def token_is_not_revoked(_jti):
        return False

    app.dependency_overrides[get_db] = override_get_db
    monkeypatch.setattr("app.core.dependencies.is_token_revoked", token_is_not_revoked)

    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


class TestDataFactory:
    """Create current-model records for integration-style tests."""

    @staticmethod
    async def create_test_user(
        session: AsyncSession,
        email: str = "test@example.com",
        password: str = "password",
        role: str = "user",
        status: str = "active",
    ) -> User:
        user = User(
            email=email,
            password_hash=hash_password(password),
            first_name="Test",
            last_name="User",
            role=role,
            status=status,
            is_deleted=False,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        return user

    @staticmethod
    async def create_test_translation(
        session: AsyncSession,
        user_id: int,
        source_text: str = "Hello",
        target_language: str = "vi",
        translation_type: str = "text",
    ) -> Translation:
        translation = Translation(
            id=time.time_ns(),
            user_id=user_id,
            source_text=source_text,
            translated_text="Xin chao",
            target_language=target_language,
            source_language="en",
            translation_type=translation_type,
            is_deleted=False,
        )
        session.add(translation)
        await session.commit()
        await session.refresh(translation)
        return translation

    @staticmethod
    async def create_api_metric(
        session: AsyncSession,
        user_id: int | None = None,
        endpoint: str = "translation/text",
        status_code: int = 200,
        response_time_ms: int = 245,
        is_ai_request: bool = True,
    ) -> ApiMetric:
        metric = ApiMetric(
            user_id=user_id,
            endpoint=endpoint,
            response_time_ms=response_time_ms,
            status_code=status_code,
            is_ai_request=is_ai_request,
            ai_model="test-model",
            ai_tokens_used=10,
        )
        session.add(metric)
        await session.commit()
        await session.refresh(metric)
        return metric


@pytest.fixture
def test_factory() -> TestDataFactory:
    """Provide integration-style test data factories."""
    return TestDataFactory()


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession, test_factory: TestDataFactory) -> User:
    """Create the standard authenticated user used by E2E workflows."""
    return await test_factory.create_test_user(db_session)


@pytest.fixture
def auth_headers(test_user: User) -> dict[str, str]:
    """Create an access token for the standard E2E user."""
    token, _ = create_access_token(data={"sub": str(test_user.id)})
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def admin_user(db_session: AsyncSession, test_factory: TestDataFactory) -> User:
    """Create an authenticated admin used by admin E2E workflows."""
    return await test_factory.create_test_user(
        db_session,
        email="admin@example.com",
        role="admin",
    )


@pytest.fixture
def admin_headers(admin_user: User) -> dict[str, str]:
    """Create an access token for the admin E2E user."""
    token, _ = create_access_token(data={"sub": str(admin_user.id)})
    return {"Authorization": f"Bearer {token}"}
