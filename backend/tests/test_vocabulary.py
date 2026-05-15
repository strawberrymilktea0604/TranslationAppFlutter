"""
Test file for Vocabulary API endpoints
Run with: pytest backend/tests/test_vocabulary.py
"""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import get_db
from app.models.base import Base
from app.models.user import User
from app.models.translation import Translation, Vocabulary
from app.core.security import hash_password, create_access_token


def auth_headers(user: User) -> dict[str, str]:
    token, _ = create_access_token(data={"sub": str(user.id)})
    return {"Authorization": f"Bearer {token}"}


# Test database setup
@pytest_asyncio.fixture
async def test_db():
    """Create test database session"""
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False,
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(
            Base.metadata.create_all,
            tables=[User.__table__, Translation.__table__, Vocabulary.__table__],
        )
    
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session
    
    await engine.dispose()


@pytest.fixture
def client(test_db, monkeypatch):
    """Create test client"""
    async def override_get_db():
        yield test_db

    async def is_token_revoked(_jti):
        return False

    app.dependency_overrides[get_db] = override_get_db
    monkeypatch.setattr("app.core.dependencies.is_token_revoked", is_token_revoked)

    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_user(test_db):
    """Create test user"""
    user = User(
        id=1,
        email="test@example.com",
        password_hash=hash_password("password123"),
        first_name="Test",
        last_name="User",
        role="user"
    )
    test_db.add(user)
    await test_db.commit()
    await test_db.refresh(user)
    return user


@pytest_asyncio.fixture
async def test_translations(test_db, test_user):
    """Create test translations"""
    import time
    import random
    
    translations = []
    for i in range(5):
        unique_id = (int(time.time() * 1000) << 22) | random.randint(0, 4194303)
        trans = Translation(
            id=unique_id,
            user_id=test_user.id,
            source_language="en",
            target_language="vi",
            source_text=f"Hello {i}",
            translated_text=f"Xin chào {i}",
            translation_type="text"
        )
        test_db.add(trans)
        translations.append(trans)
    
    await test_db.commit()
    for trans in translations:
        await test_db.refresh(trans)
    
    return translations


# ==================== TESTS ====================

@pytest.mark.asyncio
async def test_add_to_vocabulary(client, test_db, test_user, test_translations):
    """Test adding a translation to vocabulary"""
    response = client.post(
        "/api/v1/vocabularies",
        headers=auth_headers(test_user),
        json={"translation_id": test_translations[0].id}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "success"
    assert "vocabulary_id" in data["data"]


@pytest.mark.asyncio
async def test_add_duplicate_to_vocabulary(
    client, test_db, test_user, test_translations
):
    """Test that adding same translation twice fails"""
    
    translation_id = test_translations[0].id
    
    # Add first time
    response1 = client.post(
        "/api/v1/vocabularies",
        headers=auth_headers(test_user),
        json={"translation_id": translation_id}
    )
    assert response1.status_code == 201
    
    # Try to add again
    response2 = client.post(
        "/api/v1/vocabularies",
        headers=auth_headers(test_user),
        json={"translation_id": translation_id}
    )
    assert response2.status_code == 400
    assert "already in vocabulary" in response2.json()["detail"]


@pytest.mark.asyncio
async def test_add_multiple_to_vocabulary(client, test_db, test_user, test_translations):
    """Test adding multiple translations at once"""
    translation_ids = [t.id for t in test_translations[:3]]
    
    response = client.post(
        "/api/v1/vocabularies/batch",
        headers=auth_headers(test_user),
        json={"translation_ids": translation_ids}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["data"]["count"] == 3


@pytest.mark.asyncio
async def test_list_vocabularies(client, test_db, test_user, test_translations):
    """Test listing vocabulary entries"""
    # Add some to vocabulary first
    trans_ids = [t.id for t in test_translations[:2]]
    
    client.post(
        "/api/v1/vocabularies/batch",
        headers=auth_headers(test_user),
        json={"translation_ids": trans_ids}
    )
    
    # List them
    response = client.get(
        "/api/v1/vocabularies",
        headers=auth_headers(test_user)
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2
    assert data["page"] == 1
    assert data["page_size"] == 20


@pytest.mark.asyncio
async def test_search_vocabularies(client, test_db, test_user, test_translations):
    """Test searching in vocabulary"""
    # Add to vocabulary
    trans_ids = [t.id for t in test_translations[:2]]
    client.post(
        "/api/v1/vocabularies/batch",
        headers=auth_headers(test_user),
        json={"translation_ids": trans_ids}
    )
    
    # Search
    response = client.get(
        "/api/v1/vocabularies?search=Hello",
        headers=auth_headers(test_user)
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2  # Should match "Hello 0" and "Hello 1"


@pytest.mark.asyncio
async def test_remove_from_vocabulary(client, test_db, test_user, test_translations):
    """Test removing from vocabulary"""
    # Add first
    add_response = client.post(
        "/api/v1/vocabularies",
        headers=auth_headers(test_user),
        json={"translation_id": test_translations[0].id}
    )
    vocab_id = add_response.json()["data"]["vocabulary_id"]
    
    # Remove
    remove_response = client.delete(
        f"/api/v1/vocabularies/{vocab_id}",
        headers=auth_headers(test_user)
    )
    
    assert remove_response.status_code == 200
    assert remove_response.json()["status"] == "success"


@pytest.mark.asyncio
async def test_remove_multiple_from_vocabulary(
    client, test_db, test_user, test_translations
):
    """Test removing multiple from vocabulary"""
    # Add multiple
    trans_ids = [t.id for t in test_translations[:3]]
    add_response = client.post(
        "/api/v1/vocabularies/batch",
        headers=auth_headers(test_user),
        json={"translation_ids": trans_ids}
    )
    vocab_ids = add_response.json()["data"]["vocabulary_ids"]
    
    # Remove multiple
    remove_response = client.request(
        "DELETE",
        "/api/v1/vocabularies/batch/remove",
        headers=auth_headers(test_user),
        json={"translation_ids": vocab_ids}
    )
    
    assert remove_response.status_code == 200
    assert remove_response.json()["data"]["count"] == 3


@pytest.mark.asyncio
async def test_restore_vocabulary(client, test_db, test_user, test_translations):
    """Test restoring deleted vocabulary entry"""
    # Add
    add_response = client.post(
        "/api/v1/vocabularies",
        headers=auth_headers(test_user),
        json={"translation_id": test_translations[0].id}
    )
    vocab_id = add_response.json()["data"]["vocabulary_id"]
    
    # Delete
    client.delete(
        f"/api/v1/vocabularies/{vocab_id}",
        headers=auth_headers(test_user)
    )
    
    # Restore
    restore_response = client.post(
        f"/api/v1/vocabularies/{vocab_id}/restore",
        headers=auth_headers(test_user)
    )
    
    assert restore_response.status_code == 200
    assert restore_response.json()["status"] == "success"


@pytest.mark.asyncio
async def test_unauthorized_access(client):
    """Test that unauthorized users cannot access"""
    response = client.get("/api/v1/vocabularies")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_pagination(client, test_db, test_user, test_translations):
    """Test pagination"""
    # Add all translations
    trans_ids = [t.id for t in test_translations]
    client.post(
        "/api/v1/vocabularies/batch",
        headers=auth_headers(test_user),
        json={"translation_ids": trans_ids}
    )
    
    # Get page 1 with page_size=2
    response = client.get(
        "/api/v1/vocabularies?page=1&page_size=2",
        headers=auth_headers(test_user)
    )
    
    data = response.json()
    assert data["page"] == 1
    assert data["page_size"] == 2
    assert len(data["items"]) == 2
    assert data["total_pages"] == 3
    assert data["has_next"] is True
    assert data["has_prev"] is False


# ==================== STATISTICS TESTS ====================

@pytest.mark.asyncio
async def test_vocabulary_stats(client, test_db, test_user, test_translations):
    """Test getting vocabulary statistics"""
    # Add some to vocabulary
    trans_ids = [t.id for t in test_translations[:2]]
    client.post(
        "/api/v1/vocabularies/batch",
        headers=auth_headers(test_user),
        json={"translation_ids": trans_ids}
    )
    
    # Get stats
    response = client.get(
        "/api/v1/vocabularies/stats/summary",
        headers=auth_headers(test_user)
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["data"]["total_entries"] == 2
    assert "by_type" in data["data"]


# ==================== RUN TESTS ====================

if __name__ == "__main__":
    pytest.main([__file__, "-v"])

