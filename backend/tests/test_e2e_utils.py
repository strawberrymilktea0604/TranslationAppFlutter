"""
Test utilities and fixtures for E2E tests.

Provides common utilities for end-to-end testing including:
- API client setup
- Database fixtures
- Authentication helpers
- Test data factories
"""

import os
from typing import AsyncGenerator, Generator
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

from app.core.database import get_db, Base
from app.main import app


@pytest.fixture
def test_db_url():
    """Get the test database URL from environment or use default."""
    db_url = os.getenv(
        "DATABASE_URL",
        "postgresql://postgres:test_password@localhost:5433/translation_app_test"
    )
    return db_url


@pytest.fixture
def db_engine(test_db_url):
    """Create a test database engine."""
    engine = create_engine(
        test_db_url,
        echo=False,
        pool_pre_ping=True,
        poolclass=StaticPool,
    )

    # Create tables
    Base.metadata.create_all(bind=engine)

    yield engine

    # Cleanup
    Base.metadata.drop_all(bind=engine)
    engine.dispose()


@pytest.fixture
def db_session(db_engine) -> Generator[Session, None, None]:
    """Create a fresh database session for each test."""
    connection = db_engine.connect()
    transaction = connection.begin()
    session = sessionmaker(autocommit=False, autoflush=False, bind=connection)()

    def override_get_db():
        yield session

    app.dependency_overrides[get_db] = override_get_db

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session: Session) -> TestClient:
    """Create a test client with database session."""
    return TestClient(app)


@pytest.fixture
def auth_headers(client: TestClient) -> dict:
    """
    Get authentication headers for API requests.
    
    In a real scenario, this would create a test user and obtain a token.
    For now, returns empty headers (adjust based on your auth implementation).
    """
    return {"Authorization": "Bearer test-token"}


class TestDataFactory:
    """Factory for creating test data."""

    @staticmethod
    def create_test_user(
        session: Session,
        email: str = "test@example.com",
        role: str = "user",
        status: str = "active",
    ):
        """Create a test user (implement based on your User model)."""
        # Example implementation - adjust based on your actual models
        from app.models.user import User

        user = User(
            email=email,
            first_name="Test",
            last_name="User",
            role=role,
            status=status,
            is_deleted=False,
            created_at=datetime.now(timezone.utc),
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return user

    @staticmethod
    def create_test_translation_history(
        session: Session,
        user_id: int,
        source_text: str = "Hello",
        target_language: str = "vi",
    ):
        """Create a test translation history entry."""
        from app.models.translation_history import TranslationHistory

        history = TranslationHistory(
            user_id=user_id,
            source_text=source_text,
            translated_text="Xin chào",
            target_language=target_language,
            source_language="en",
            translation_service="google",
            created_at=datetime.now(timezone.utc),
        )
        session.add(history)
        session.commit()
        session.refresh(history)
        return history


@pytest.fixture
def test_factory(db_session: Session) -> TestDataFactory:
    """Provide test data factory."""
    return TestDataFactory()
