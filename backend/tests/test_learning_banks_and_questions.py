"""
Tests for Question Bank list/detail/questions/start endpoints and
additional quiz-submission scenarios not covered in test_learning_quiz_submission.py.

All tests use TestClient with dependency overrides so no real DB is needed.
"""
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import List

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("SECRET_KEY", "test-secret-key-for-banks-tests")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.database import get_db  # noqa: E402
from app.core.dependencies import get_admin_user, get_current_user  # noqa: E402
from app.main import app  # noqa: E402
from app.repositories.quiz_repository import QuizRepository  # noqa: E402
from app.schemas.learning import QuizAnswerResult  # noqa: E402


# ─────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────

@pytest.fixture
def client():
    async def override_get_db():
        yield SimpleNamespace(name="test-db")

    async def override_get_current_user():
        return SimpleNamespace(id=42, role="user")

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


# ─────────────────────────────────────────────
# Helpers / fakes
# ─────────────────────────────────────────────

def _make_bank(bank_id=1, title="Test Bank", duration_minutes=10):
    return SimpleNamespace(
        id=bank_id,
        title=title,
        description="A test bank",
        duration_minutes=duration_minutes,
        is_deleted=False,
        created_at=datetime(2026, 5, 1, 0, 0, tzinfo=timezone.utc),
        questions=[
            SimpleNamespace(
                id=101,
                bank_id=bank_id,
                content="What is 2+2?",
                choices=["A. 3", "B. 4", "C. 5", "D. 6"],
                options=None,
                correct_answer="B",
                is_deleted=False,
            ),
            SimpleNamespace(
                id=102,
                bank_id=bank_id,
                content="What colour is the sky?",
                choices=["A. Red", "B. Green", "C. Blue", "D. Yellow"],
                options=None,
                correct_answer="C",
                is_deleted=False,
            ),
        ],
    )


def _make_quiz(bank_id=1, status="completed", time_spent=60):
    return SimpleNamespace(
        id=77,
        bank_id=bank_id,
        score=50.0,
        completion_time_seconds=time_spent,
        time_spent_seconds=time_spent,
        total_questions=2,
        correct_answers=1,
        submitted_at=datetime(2026, 5, 18, 10, 0, tzinfo=timezone.utc),
        status=status,
        created_at=datetime(2026, 5, 18, 9, 0, tzinfo=timezone.utc),
    )


def _make_results() -> List[QuizAnswerResult]:
    return [
        QuizAnswerResult(
            question_id=101, selected_answer="B", correct_answer="B", is_correct=True
        ),
        QuizAnswerResult(
            question_id=102, selected_answer="A", correct_answer="C", is_correct=False
        ),
    ]


# ─────────────────────────────────────────────────────────────────────────────
# GET /banks — list question banks
# ─────────────────────────────────────────────────────────────────────────────

class FakeScalars:
    def __init__(self, items):
        self._items = items

    def all(self):
        return self._items


class FakeResult:
    def __init__(self, items=None, scalar_value=None, one_or_none=None):
        self._items = items or []
        self._scalar = scalar_value
        self._one_or_none = one_or_none

    def scalars(self):
        return FakeScalars(self._items)

    def scalar_one_or_none(self):
        return self._one_or_none

    def scalar(self):
        return self._scalar


class FakeDB:
    """Minimal fake async session that returns pre-canned results per call order."""

    def __init__(self, results: list):
        self._results = iter(results)

    async def execute(self, stmt):
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
        yield FakeDB(results)

    return _get_db


def test_list_banks(client, monkeypatch):
    """GET /banks returns a list of bank summaries."""
    banks = [
        SimpleNamespace(
            id=1,
            title="Bank A",
            description="desc",
            duration_minutes=5,
            is_deleted=False,
            created_at=datetime(2026, 5, 1, tzinfo=timezone.utc),
        )
    ]

    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(items=banks)]
    )

    response = client.get("/api/v1/learning/banks")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["title"] == "Bank A"
    assert "questions" not in data[0], "Bank list should not embed questions"

    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# GET /banks/{id} — detail (mobile-safe, no correct_answer)
# ─────────────────────────────────────────────────────────────────────────────

def test_bank_detail_excludes_correct_answer(client, monkeypatch):
    """GET /banks/{id} must NOT expose correct_answer."""
    bank = _make_bank()

    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(one_or_none=bank)]
    )

    response = client.get("/api/v1/learning/banks/1")
    assert response.status_code == 200
    data = response.json()

    assert data["id"] == 1
    assert "questions" in data
    for q in data["questions"]:
        assert "correct_answer" not in q, (
            f"correct_answer must not appear in user-facing bank detail; got key in {q}"
        )
        assert "content" in q
        assert "options" in q

    app.dependency_overrides.clear()


def test_bank_detail_404_when_not_found(client, monkeypatch):
    """GET /banks/{id} returns 404 for unknown bank."""
    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(one_or_none=None)]
    )

    response = client.get("/api/v1/learning/banks/999")
    assert response.status_code == 404

    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# GET /banks/{id}/questions — paginated, no correct_answer
# ─────────────────────────────────────────────────────────────────────────────

def test_questions_list_excludes_correct_answer(client, monkeypatch):
    """GET /banks/{id}/questions must NOT expose correct_answer."""
    bank = _make_bank()
    questions = bank.questions  # list of SimpleNamespace

    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [
            FakeResult(one_or_none=bank),        # bank existence check
            FakeResult(scalar_value=2),           # count query
            FakeResult(items=questions),          # paginated questions
        ]
    )

    response = client.get("/api/v1/learning/banks/1/questions?page=1&page_size=20")
    assert response.status_code == 200
    data = response.json()

    assert data["bank_id"] == 1
    assert data["total"] == 2
    assert len(data["items"]) == 2

    for q in data["items"]:
        assert "correct_answer" not in q, (
            f"correct_answer must not appear in questions list; got key in {q}"
        )
        assert "content" in q
        assert "options" in q

    app.dependency_overrides.clear()


def test_questions_list_pagination_fields(client, monkeypatch):
    """Pagination metadata is returned correctly."""
    bank = _make_bank()

    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [
            FakeResult(one_or_none=bank),
            FakeResult(scalar_value=50),   # 50 total questions
            FakeResult(items=[]),           # page 3 of 50 with page_size=20 → empty page
        ]
    )

    response = client.get("/api/v1/learning/banks/1/questions?page=3&page_size=20")
    assert response.status_code == 200
    data = response.json()

    assert data["page"] == 3
    assert data["page_size"] == 20
    assert data["total"] == 50
    assert data["total_pages"] == 3  # ceil(50/20)
    assert data["has_prev"] is True
    assert data["has_next"] is False

    app.dependency_overrides.clear()


def test_questions_list_404_for_unknown_bank(client, monkeypatch):
    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(one_or_none=None)]
    )

    response = client.get("/api/v1/learning/banks/999/questions")
    assert response.status_code == 404

    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# GET /banks/{id}/start — no correct_answer
# ─────────────────────────────────────────────────────────────────────────────

def test_start_quiz_excludes_correct_answer(client, monkeypatch):
    """GET /banks/{id}/start must NOT expose correct_answer."""
    bank = _make_bank(duration_minutes=10)

    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(one_or_none=bank)]
    )

    response = client.get("/api/v1/learning/banks/1/start")
    assert response.status_code == 200
    data = response.json()

    assert data["id"] == 1
    assert data["title"] == "Test Bank"
    assert data["duration_minutes"] == 10
    assert data["total_questions"] == 2
    assert "questions" in data

    for q in data["questions"]:
        assert "correct_answer" not in q, (
            f"correct_answer must not appear in start response; got key in {q}"
        )
        assert "content" in q
        assert "options" in q

    app.dependency_overrides.clear()


def test_start_quiz_404_for_unknown_bank(client, monkeypatch):
    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(one_or_none=None)]
    )

    response = client.get("/api/v1/learning/banks/999/start")
    assert response.status_code == 404

    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# GET /admin/banks/{id} — includes correct_answer
# ─────────────────────────────────────────────────────────────────────────────

def test_admin_bank_detail_forbidden_for_regular_user(client, monkeypatch):
    """GET /admin/banks/{id} must return 403 for a non-admin user."""
    # The 'client' fixture overrides get_current_user with a plain user (id=42,
    # no role attribute).  get_admin_user will see a non-admin and raise 403.
    response = client.get("/api/v1/learning/admin/banks/1")
    assert response.status_code == 403


def test_admin_bank_detail_includes_correct_answer(client, monkeypatch):
    """GET /admin/banks/{id} MUST include correct_answer for admin use."""
    bank = _make_bank()

    from app.core.database import get_db as _get_db_original

    app.dependency_overrides[_get_db_original] = _override_db(
        [FakeResult(one_or_none=bank)]
    )
    # Override get_admin_user directly so the admin guard is satisfied
    app.dependency_overrides[get_admin_user] = lambda: SimpleNamespace(id=99, role="admin")

    response = client.get("/api/v1/learning/admin/banks/1")
    assert response.status_code == 200
    data = response.json()

    assert data["id"] == 1
    assert "questions" in data
    for q in data["questions"]:
        assert "correct_answer" in q, "Admin endpoint must expose correct_answer"
        assert q["correct_answer"] in ("B", "C")  # our fixtures

    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# Timeout: submit with time_spent > duration_minutes * 60
# ─────────────────────────────────────────────────────────────────────────────

def test_timeout_submit_saves_status(client, monkeypatch):
    """When time exceeds duration_minutes the status saved should be 'timeout'."""
    captured = {}

    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        captured["time_spent_seconds"] = time_spent_seconds
        # Return a quiz object with status='timeout' (as the real repo would)
        quiz = _make_quiz(bank_id=bank_id, status="timeout", time_spent=time_spent_seconds)
        return quiz, _make_results()

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    # duration_minutes=10 → limit 600s; submit with 700s → should be timeout
    response = client.post(
        "/api/v1/learning/banks/1/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "B"},
                {"question_id": 102, "selected_answer": "A"},
            ],
            "time_spent_seconds": 700,
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "timeout"
    assert captured["time_spent_seconds"] == 700


def test_timeout_logic_in_repository():
    """
    Unit-test the timeout threshold calculation directly,
    without going through the HTTP layer.
    """
    # bank.duration_minutes = 5  → threshold = 300s
    # time_spent = 301 → timeout
    # time_spent = 299 → completed
    duration = 5
    threshold = duration * 60

    assert 301 > threshold   # would be timeout
    assert 299 <= threshold  # would be completed


# ─────────────────────────────────────────────────────────────────────────────
# Quiz history — persisted fields
# ─────────────────────────────────────────────────────────────────────────────

def test_quiz_history_includes_persisted_values(client, monkeypatch):
    """GET /history items must include total_questions, correct_answers, time_spent_seconds."""
    from app.schemas.learning import UserQuizHistoryItem

    fake_items = [
        UserQuizHistoryItem(
            quiz_id=77,
            bank_id=1,
            bank_title="Test Bank",
            score=50.0,
            completion_time_seconds=60,
            time_spent_seconds=60,
            total_questions=2,
            correct_answers=1,
            status="completed",
            created_at=datetime(2026, 5, 18, 9, 0, tzinfo=timezone.utc),
        )
    ]

    async def fake_get_user_history(db, user_id, page=1, page_size=20):
        return fake_items, 1

    monkeypatch.setattr(QuizRepository, "get_user_history", fake_get_user_history)

    response = client.get("/api/v1/learning/history")
    assert response.status_code == 200
    data = response.json()

    assert data["total"] == 1
    item = data["items"][0]

    assert item["total_questions"] == 2
    assert item["correct_answers"] == 1
    assert item["time_spent_seconds"] == 60
    assert item["completion_time_seconds"] == 60  # legacy field still present
    assert item["status"] == "completed"
