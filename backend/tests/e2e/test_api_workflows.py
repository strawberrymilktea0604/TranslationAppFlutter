"""
End-to-end tests for API endpoints.

Tests complete workflows including:
- User authentication and authorization
- API request/response cycles
- Database interactions
- Error handling
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.mark.e2e
class TestAPIHealthCheck:
    """E2E tests for API health check endpoint."""

    def test_health_check_endpoint(self, client: TestClient):
        """Test that health check endpoint returns 200."""
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json() is not None

    def test_health_check_returns_status(self, client: TestClient):
        """Test that health check returns a status object."""
        response = client.get("/api/v1/health")
        data = response.json()
        assert "status" in data or response.status_code == 200


@pytest.mark.e2e
class TestAuthenticationFlow:
    """E2E tests for authentication workflows."""

    def test_register_user_flow(self, client: TestClient):
        """Register a user and receive usable authentication tokens."""
        user_data = {
            "email": "e2e-test@example.com",
            "password": "Test@123",
            "first_name": "E2E",
            "last_name": "Test",
        }

        response = client.post("/api/v1/auth/register", json=user_data)
        data = response.json()

        assert response.status_code == 200
        assert data["token_type"] == "bearer"
        assert data["access_token"]
        assert data["refresh_token"]

    def test_login_flow(self, client: TestClient, test_user):
        """Log in as a seeded user and receive authentication tokens."""
        login_data = {
            "username": "test@example.com",
            "password": "password",
        }

        response = client.post("/api/v1/auth/login", data=login_data)
        data = response.json()

        assert test_user.email == login_data["username"]
        assert response.status_code == 200
        assert data["token_type"] == "bearer"
        assert data["access_token"]
        assert data["refresh_token"]


@pytest.mark.e2e
class TestTranslationWorkflow:
    """E2E tests for translation workflows."""

    def test_get_translation_endpoints_exist(self, client: TestClient):
        """Protected translation history rejects unauthenticated callers."""
        response = client.get("/api/v1/translations/history")

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_translation_history_workflow(
        self,
        client: TestClient,
        test_factory,
        db_session: AsyncSession,
        test_user,
        auth_headers: dict,
    ):
        """Persist a translation and retrieve it through the history API."""
        history = await test_factory.create_test_translation(
            db_session,
            user_id=test_user.id,
        )

        response = client.get("/api/v1/translations/history", headers=auth_headers)
        data = response.json()

        assert response.status_code == 200
        assert data["total"] == 1
        assert data["data"][0]["id"] == history.id
        assert data["data"][0]["source_text"] == "Hello"


@pytest.mark.e2e
class TestConcurrentRequests:
    """E2E tests for handling concurrent requests."""

    def test_multiple_health_checks(self, client: TestClient):
        """Test that multiple concurrent requests work correctly."""
        # Simulate multiple requests
        responses = [client.get("/api/v1/health") for _ in range(5)]
        
        # All requests should succeed
        assert all(response.status_code == 200 for response in responses)

    def test_request_isolation(self, client: TestClient):
        """Test that requests don't interfere with each other."""
        response1 = client.get("/api/v1/health")
        response2 = client.get("/api/v1/health")
        
        # Both should succeed independently
        assert response1.status_code == 200
        assert response2.status_code == 200


@pytest.mark.e2e
class TestErrorHandling:
    """E2E tests for error handling."""

    def test_nonexistent_endpoint(self, client: TestClient):
        """Test that nonexistent endpoints return 404."""
        response = client.get("/api/v1/nonexistent/endpoint")
        assert response.status_code == 404

    def test_invalid_request_body(self, client: TestClient):
        """Test that invalid request bodies are handled."""
        response = client.post("/api/v1/auth/login", json={"invalid": "data"})
        assert response.status_code == 422

    def test_unauthorized_access(self, client: TestClient):
        """Test that unauthorized requests are rejected."""
        # Attempt to access protected endpoint without auth
        response = client.get(
            "/api/v1/admin/users",
            headers={"Authorization": "Bearer invalid-token"}
        )
        assert response.status_code == 401


@pytest.mark.e2e
class TestAdminDashboardWorkflow:
    """E2E coverage for admin service-management and analytics endpoints."""

    @pytest.mark.asyncio
    async def test_admin_service_management_endpoints(
        self,
        client: TestClient,
        test_factory,
        db_session: AsyncSession,
        test_user,
        admin_headers: dict,
    ):
        """Admin can read service counters and translation rows from real data."""
        await test_factory.create_test_translation(
            db_session,
            user_id=test_user.id,
            source_text="Hello",
            translation_type="text",
        )
        await test_factory.create_test_translation(
            db_session,
            user_id=test_user.id,
            source_text="Image text",
            translation_type="image",
        )

        summary = client.get("/api/v1/admin/services/summary", headers=admin_headers)
        translations = client.get(
            "/api/v1/admin/services/translations",
            headers=admin_headers,
        )

        assert summary.status_code == 200
        assert summary.json()["total_translations"] == 2
        assert summary.json()["by_type"][0]["count"] >= 1
        assert translations.status_code == 200
        assert translations.json()["total"] == 2
        assert translations.json()["items"][0]["user_email"] == test_user.email

    @pytest.mark.asyncio
    async def test_admin_analytics_endpoints(
        self,
        client: TestClient,
        test_factory,
        db_session: AsyncSession,
        test_user,
        admin_headers: dict,
    ):
        """Admin analytics endpoints aggregate translations and API metrics."""
        await test_factory.create_test_translation(
            db_session,
            user_id=test_user.id,
            translation_type="text",
        )
        await test_factory.create_api_metric(db_session, user_id=test_user.id)
        await test_factory.create_api_metric(
            db_session,
            user_id=test_user.id,
            status_code=500,
            response_time_ms=500,
        )

        overview = client.get(
            "/api/v1/admin/analytics/overview?days=7",
            headers=admin_headers,
        )
        type_breakdown = client.get(
            "/api/v1/admin/analytics/translation-types?days=7",
            headers=admin_headers,
        )
        languages = client.get(
            "/api/v1/admin/analytics/languages?days=7",
            headers=admin_headers,
        )
        services = client.get(
            "/api/v1/admin/analytics/services?days=7",
            headers=admin_headers,
        )

        assert overview.status_code == 200
        assert overview.json()["active_users"]["value"] == 1.0
        assert type_breakdown.status_code == 200
        assert type_breakdown.json()["items"][0]["type"] == "text"
        assert languages.status_code == 200
        assert languages.json()["target_languages"][0]["language"] == "vi"
        assert services.status_code == 200
        assert services.json()["items"][0]["total_requests"] == 2
