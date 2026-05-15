"""
Test file for Vocabulary API endpoints
Run with: pytest backend/tests/test_vocabulary.py
"""

import pytest
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

from app.main import app
from app.core.database import Base
from app.models.user import User
from app.models.translation import Translation
from app.core.security import hash_password, create_access_token


# Test database setup
@pytest.fixture
async def test_db():
    """Create test database session"""
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        echo=False,
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session
    
    await engine.dispose()


@pytest.fixture
def client():
    """Create test client"""
    return TestClient(app)


@pytest.fixture
async def test_user(test_db):
    """Create test user"""
    user = User(
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


@pytest.fixture
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
    token = create_access_token(data={"sub": test_user.email})
    
    response = client.post(
        "/api/v1/vocabularies",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_id": test_translations[0].id}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["success"] is True
    assert "vocabulary_id" in data["data"]


@pytest.mark.asyncio
async def test_add_duplicate_to_vocabulary(
    client, test_db, test_user, test_translations
):
    """Test that adding same translation twice fails"""
    
    token = create_access_token(data={"sub": test_user.email})
    translation_id = test_translations[0].id
    
    # Add first time
    response1 = client.post(
        "/api/v1/vocabularies",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_id": translation_id}
    )
    assert response1.status_code == 201
    
    # Try to add again
    response2 = client.post(
        "/api/v1/vocabularies",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_id": translation_id}
    )
    assert response2.status_code == 400
    assert "already in vocabulary" in response2.json()["detail"]


@pytest.mark.asyncio
async def test_add_multiple_to_vocabulary(client, test_db, test_user, test_translations):
    """Test adding multiple translations at once"""
    token = create_access_token(data={"sub": test_user.email})
    
    translation_ids = [t.id for t in test_translations[:3]]
    
    response = client.post(
        "/api/v1/vocabularies/batch",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": translation_ids}
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["data"]["count"] == 3


@pytest.mark.asyncio
async def test_list_vocabularies(client, test_db, test_user, test_translations):
    """Test listing vocabulary entries"""
    token = create_access_token(data={"sub": test_user.email})
    
    # Add some to vocabulary first
    trans_ids = [t.id for t in test_translations[:2]]
    
    client.post(
        "/api/v1/vocabularies/batch",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": trans_ids}
    )
    
    # List them
    response = client.get(
        "/api/v1/vocabularies",
        headers={"Authorization": f"Bearer {token}"}
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
    token = create_access_token(data={"sub": test_user.email})
    
    # Add to vocabulary
    trans_ids = [t.id for t in test_translations[:2]]
    client.post(
        "/api/v1/vocabularies/batch",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": trans_ids}
    )
    
    # Search
    response = client.get(
        "/api/v1/vocabularies?search=Hello",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2  # Should match "Hello 0" and "Hello 1"


@pytest.mark.asyncio
async def test_remove_from_vocabulary(client, test_db, test_user, test_translations):
    """Test removing from vocabulary"""
    token = create_access_token(data={"sub": test_user.email})
    
    # Add first
    add_response = client.post(
        "/api/v1/vocabularies",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_id": test_translations[0].id}
    )
    vocab_id = add_response.json()["data"]["vocabulary_id"]
    
    # Remove
    remove_response = client.delete(
        f"/api/v1/vocabularies/{vocab_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert remove_response.status_code == 200
    assert remove_response.json()["success"] is True


@pytest.mark.asyncio
async def test_remove_multiple_from_vocabulary(
    client, test_db, test_user, test_translations
):
    """Test removing multiple from vocabulary"""
    token = create_access_token(data={"sub": test_user.email})
    
    # Add multiple
    trans_ids = [t.id for t in test_translations[:3]]
    add_response = client.post(
        "/api/v1/vocabularies/batch",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": trans_ids}
    )
    vocab_ids = add_response.json()["data"]["vocabulary_ids"]
    
    # Remove multiple
    remove_response = client.delete(
        "/api/v1/vocabularies/batch/remove",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": vocab_ids}
    )
    
    assert remove_response.status_code == 200
    assert remove_response.json()["data"]["count"] == 3


@pytest.mark.asyncio
async def test_restore_vocabulary(client, test_db, test_user, test_translations):
    """Test restoring deleted vocabulary entry"""
    token = create_access_token(data={"sub": test_user.email})
    
    # Add
    add_response = client.post(
        "/api/v1/vocabularies",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_id": test_translations[0].id}
    )
    vocab_id = add_response.json()["data"]["vocabulary_id"]
    
    # Delete
    client.delete(
        f"/api/v1/vocabularies/{vocab_id}",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    # Restore
    restore_response = client.post(
        f"/api/v1/vocabularies/{vocab_id}/restore",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert restore_response.status_code == 200
    assert restore_response.json()["success"] is True


@pytest.mark.asyncio
async def test_unauthorized_access(client):
    """Test that unauthorized users cannot access"""
    response = client.get("/api/v1/vocabularies")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_pagination(client, test_db, test_user, test_translations):
    """Test pagination"""
    token = create_access_token(data={"sub": test_user.email})
    
    # Add all translations
    trans_ids = [t.id for t in test_translations]
    client.post(
        "/api/v1/vocabularies/batch",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": trans_ids}
    )
    
    # Get page 1 with page_size=2
    response = client.get(
        "/api/v1/vocabularies?page=1&page_size=2",
        headers={"Authorization": f"Bearer {token}"}
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
    token = create_access_token(data={"sub": test_user.email})
    
    # Add some to vocabulary
    trans_ids = [t.id for t in test_translations[:2]]
    client.post(
        "/api/v1/vocabularies/batch",
        headers={"Authorization": f"Bearer {token}"},
        json={"translation_ids": trans_ids}
    )
    
    # Get stats
    response = client.get(
        "/api/v1/vocabularies/stats/summary",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["data"]["total_entries"] == 2
    assert "by_type" in data["data"]


# ==================== RUN TESTS ====================

if __name__ == "__main__":
    pytest.main([__file__, "-v"])

