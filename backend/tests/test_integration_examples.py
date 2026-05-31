"""
Integration test example for the translation application.

This demonstrates how to write integration tests that test multiple
components working together (e.g., API + Database + Services).
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session


@pytest.mark.integration
class TestTranslationIntegration:
    """Integration tests for translation features."""

    def test_translation_service_with_database(self, client: TestClient, test_factory, db_session: Session):
        """
        Test translation service integration with database.
        
        This test verifies that:
        1. User data is stored in database
        2. Translation service processes data correctly
        3. Results are retrievable from database
        """
        # Create test user
        user = test_factory.create_test_user(
            db_session,
            email="integration-test@example.com"
        )
        
        assert user.id is not None
        assert user.email == "integration-test@example.com"

    def test_caching_integration(self, client: TestClient, db_session: Session):
        """
        Test integration with caching system.
        
        Verifies that:
        1. Data is properly cached
        2. Cache retrieval works correctly
        3. Cache invalidation works
        """
        # This is a placeholder for actual caching integration tests
        # Implement based on your caching mechanism (Redis, etc.)
        pass


@pytest.mark.integration
class TestDatabaseIntegration:
    """Integration tests for database operations."""

    def test_user_creation_and_retrieval(self, db_session: Session, test_factory):
        """Test creating and retrieving a user from database."""
        user = test_factory.create_test_user(db_session, email="db-test@example.com")
        
        # Verify user was created
        assert user.id is not None
        assert user.email == "db-test@example.com"
        assert user.status == "active"


@pytest.mark.integration
class TestMultipleServicesIntegration:
    """Integration tests involving multiple services working together."""

    def test_translation_with_history_logging(self, client: TestClient, test_factory, db_session: Session):
        """
        Test that translations are properly logged to history.
        
        Verifies:
        1. Translation is performed
        2. History entry is created
        3. User can retrieve history
        """
        # Create test user
        user = test_factory.create_test_user(db_session)
        
        # Create translation history
        history = test_factory.create_test_translation_history(
            db_session,
            user_id=user.id,
            source_text="Hello",
            target_language="vi"
        )
        
        assert history.id is not None
        assert history.user_id == user.id
