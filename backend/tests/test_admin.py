"""
Tests for the Admin API — /api/v1/admin

All tests use TestClient with dependency overrides so no real DB or Redis is needed.

Coverage:
- RBAC: 401 (no token), 403 (regular user), 200 (admin)
- GET /admin/users        — pagination, filters
- PATCH /admin/users/{id}/ban   — happy path, self-ban, admin-ban, 404
- PATCH /admin/users/{id}/unban — happy path, 404
- GET /admin/question-banks     — pagination
- GET /admin/question-banks/{id} — correct_answer included, 404
- GET /learning/admin/banks/{id} — now requires admin (403 for regular user)
"""
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("SECRET_KEY", "test-secret-key-for-admin-tests")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.database import get_db
from app.core.dependencies import get_admin_user, get_current_user
from app.main import app


# ─────────────────────────────────────────────
# Shared fake objects
# ─────────────────────────────────────────────

_NOW = datetime(2026, 5, 24, 0, 0, tzinfo=timezone.utc)


def _make_user(
    user_id=1,
    email="user@example.com",
    role="user",
    status="active",
    is_deleted=False,
):
    return SimpleNamespace(
        id=user_id,
        email=email,
        first_name="Test",
        last_name="User",
        avatar_url=None,
        role=role,
        status=status,
        is_deleted=is_deleted,
        created_at=_NOW,
        updated_at=_NOW,
    )


def _make_bank(bank_id=1, title="Bank A", question_count=5):
    return SimpleNamespace(
        id=bank_id,
        title=title,
        description="desc",
        duration_minutes=10,
        is_deleted=False,
        question_count=question_count,
        created_at=_NOW,
        updated_at=_NOW,
        questions=[
            SimpleNamespace(
                id=101,
                bank_id=bank_id,
                content="Q1?",
                choices=["A", "B"],
                options=None,
                correct_answer="A",
                is_deleted=False,
            )
        ],
    )


# ─────────────────────────────────────────────
# FakeDB helpers (mirrors test_learning_banks_and_questions.py)
# ─────────────────────────────────────────────

class _FakeScalars:
    def __init__(self, items):
        self._items = items

    def all(self):
        return self._items

    def first(self):
        return self._items[0] if self._items else None


class _FakeResult:
    def __init__(self, items=None, scalar_value=None, one_or_none=None):
        self._items = items if items is not None else []
        self._scalar = scalar_value
        self._one_or_none = one_or_none

    def scalars(self):
        return _FakeScalars(self._items)

    def scalar_one_or_none(self):
        return self._one_or_none

    def scalar(self):
        return self._scalar

    def all(self):
        return self._items


class _FakeDB:
    """Minimal async session that pops pre-canned results in call order."""

    def __init__(self, results: list):
        self._results = iter(results)

    async def execute(self, _stmt):
        return next(self._results)

    async def commit(self):
        pass

    async def refresh(self, obj):
        pass

    def add(self, obj):
        pass

    async def flush(self):
        pass


def _override_db(results: list):
    async def _get_db():
        yield _FakeDB(results)
    return _get_db


# ─────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────

@pytest.fixture
def admin_client():
    """Client where get_admin_user is satisfied (admin user)."""
    admin = _make_user(user_id=99, email="admin@example.com", role="admin")

    async def _override_admin():
        return admin

    async def _override_db_stub():
        yield SimpleNamespace(name="test-db")

    app.dependency_overrides[get_admin_user] = _override_admin
    app.dependency_overrides[get_current_user] = _override_admin
    app.dependency_overrides[get_db] = _override_db_stub
    try:
        yield TestClient(app), admin
    finally:
        app.dependency_overrides.clear()


@pytest.fixture
def regular_client():
    """Client where only get_current_user is satisfied (non-admin user)."""
    user = _make_user(user_id=1, role="user")

    async def _override_user():
        return user

    async def _override_db_stub():
        yield SimpleNamespace(name="test-db")

    app.dependency_overrides[get_current_user] = _override_user
    app.dependency_overrides[get_db] = _override_db_stub
    try:
        yield TestClient(app), user
    finally:
        app.dependency_overrides.clear()


@pytest.fixture
def no_auth_client():
    """Plain TestClient — no dependency overrides (simulates missing token)."""
    try:
        yield TestClient(app, raise_server_exceptions=False)
    finally:
        app.dependency_overrides.clear()


# ═══════════════════════════════════════════════════════════════════
# RBAC — auth gate
# ═══════════════════════════════════════════════════════════════════

def test_admin_users_no_token_returns_401(no_auth_client):
    """GET /admin/users without a token must return 401."""
    resp = no_auth_client.get("/api/v1/admin/users")
    assert resp.status_code == 401


def test_admin_users_regular_user_returns_403(regular_client):
    """GET /admin/users with a non-admin token must return 403."""
    client, _ = regular_client
    resp = client.get("/api/v1/admin/users")
    assert resp.status_code == 403


def test_admin_question_banks_no_token_returns_401(no_auth_client):
    """GET /admin/question-banks without a token must return 401."""
    resp = no_auth_client.get("/api/v1/admin/question-banks")
    assert resp.status_code == 401


def test_admin_question_banks_regular_user_returns_403(regular_client):
    """GET /admin/question-banks with a non-admin token must return 403."""
    client, _ = regular_client
    resp = client.get("/api/v1/admin/question-banks")
    assert resp.status_code == 403


# ═══════════════════════════════════════════════════════════════════
# GET /admin/users
# ═══════════════════════════════════════════════════════════════════

def test_admin_can_list_users(admin_client):
    """Admin receives a paginated user list."""
    client, admin = admin_client
    users = [_make_user(user_id=i, email=f"u{i}@x.com") for i in range(1, 4)]

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(scalar_value=3),   # count query
        _FakeResult(items=users),      # paginated rows
    ])

    resp = client.get("/api/v1/admin/users")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert len(data["items"]) == 3
    assert data["items"][0]["email"] == "u1@x.com"
    # Admin-only fields present
    assert "is_deleted" in data["items"][0]
    assert "role" in data["items"][0]


def test_admin_list_users_pagination_fields(admin_client):
    """Pagination metadata is correctly populated."""
    client, _ = admin_client
    users = [_make_user(user_id=i) for i in range(1, 6)]

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(scalar_value=50),
        _FakeResult(items=users),
    ])

    resp = client.get("/api/v1/admin/users?page=2&page_size=5")
    assert resp.status_code == 200
    data = resp.json()
    assert data["page"] == 2
    assert data["page_size"] == 5
    assert data["total"] == 50
    assert data["total_pages"] == 10
    assert data["has_prev"] is True
    assert data["has_next"] is True


# ═══════════════════════════════════════════════════════════════════
# PATCH /admin/users/{id}/ban
# ═══════════════════════════════════════════════════════════════════

def test_admin_ban_user_sets_locked_and_revokes_tokens(admin_client):
    """Ban sets status=locked and returns revoked_tokens_count."""
    client, admin = admin_client

    target = _make_user(user_id=7, role="user", status="active")

    # Fake token rows to revoke
    future = datetime(2030, 1, 1, tzinfo=timezone.utc)
    fake_tokens = [
        SimpleNamespace(jti="jti-1", is_revoked=False, expires_at=future),
        SimpleNamespace(jti="jti-2", is_revoked=False, expires_at=future),
    ]

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=target),   # fetch target user
        _FakeResult(items=fake_tokens),    # fetch active tokens
    ])

    with patch("app.api.v1.endpoints.admin.set_revoked_token", new_callable=AsyncMock) as mock_revoke:
        resp = client.patch("/api/v1/admin/users/7/ban")

    assert resp.status_code == 200
    data = resp.json()
    assert data["user"]["status"] == "locked"
    assert data["revoked_tokens_count"] == 2
    assert mock_revoke.call_count == 2


def test_admin_self_ban_returns_400(admin_client):
    """Admin cannot ban their own account."""
    client, admin = admin_client
    resp = client.patch(f"/api/v1/admin/users/{admin.id}/ban")
    assert resp.status_code == 400
    assert "own account" in resp.json()["detail"].lower()


def test_admin_ban_another_admin_returns_400(admin_client):
    """Admin cannot ban another admin account in v1."""
    client, _ = admin_client
    other_admin = _make_user(user_id=50, role="admin")

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=other_admin),
    ])

    resp = client.patch("/api/v1/admin/users/50/ban")
    assert resp.status_code == 400
    assert "admin" in resp.json()["detail"].lower()


def test_admin_ban_missing_user_returns_404(admin_client):
    """Banning a non-existent user returns 404."""
    client, _ = admin_client

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=None),
    ])

    resp = client.patch("/api/v1/admin/users/9999/ban")
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════
# PATCH /admin/users/{id}/unban
# ═══════════════════════════════════════════════════════════════════

def test_admin_unban_user_sets_active(admin_client):
    """Unban sets status=active and returns updated user."""
    client, _ = admin_client
    target = _make_user(user_id=8, status="locked")

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=target),
    ])

    resp = client.patch("/api/v1/admin/users/8/unban")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "active"


def test_admin_unban_missing_user_returns_404(admin_client):
    """Unbanning a non-existent user returns 404."""
    client, _ = admin_client

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=None),
    ])

    resp = client.patch("/api/v1/admin/users/9999/unban")
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════
# GET /admin/question-banks
# ═══════════════════════════════════════════════════════════════════

def test_admin_can_list_question_banks(admin_client):
    """Admin receives a paginated bank list with question_count."""
    client, _ = admin_client
    banks = [(_make_bank(bank_id=i, title=f"Bank {i}", question_count=3), 3) for i in range(1, 4)]

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(scalar_value=3),   # total count
        _FakeResult(items=banks),      # bank rows (tuples)
    ])

    resp = client.get("/api/v1/admin/question-banks")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert len(data["items"]) == 3
    assert data["items"][0]["question_count"] == 3
    assert "is_deleted" in data["items"][0]


# ═══════════════════════════════════════════════════════════════════
# GET /admin/question-banks/{bank_id}
# ═══════════════════════════════════════════════════════════════════

def test_admin_bank_detail_includes_correct_answer(admin_client):
    """Admin bank detail MUST include correct_answer on each question."""
    client, _ = admin_client
    bank = _make_bank()

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=bank),
    ])

    resp = client.get("/api/v1/admin/question-banks/1")
    assert resp.status_code == 200
    data = resp.json()
    assert "questions" in data
    for q in data["questions"]:
        assert "correct_answer" in q, "Admin bank detail must expose correct_answer"


def test_admin_bank_detail_404(admin_client):
    """Non-existent bank returns 404."""
    client, _ = admin_client

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=None),
    ])

    resp = client.get("/api/v1/admin/question-banks/9999")
    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════
# GET /learning/admin/banks/{id} — now requires admin
# ═══════════════════════════════════════════════════════════════════

def test_learning_admin_bank_regular_user_forbidden(regular_client):
    """Regular user must get 403 from /learning/admin/banks/{id}."""
    client, _ = regular_client
    resp = client.get("/api/v1/learning/admin/banks/1")
    assert resp.status_code == 403


def test_learning_admin_bank_admin_sees_correct_answer(admin_client):
    """Admin gets correct_answer from /learning/admin/banks/{id}."""
    client, _ = admin_client
    bank = _make_bank()

    app.dependency_overrides[get_db] = _override_db([
        _FakeResult(one_or_none=bank),
    ])

    resp = client.get("/api/v1/learning/admin/banks/1")
    assert resp.status_code == 200
    data = resp.json()
    for q in data["questions"]:
        assert "correct_answer" in q
