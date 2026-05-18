from datetime import datetime, timezone
import os
from pathlib import Path
from types import SimpleNamespace
import sys

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("SECRET_KEY", "test-secret-key-for-quiz-submission-tests")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.main import app
from app.repositories.quiz_repository import QuizRepository
from app.schemas.learning import QuizAnswerResult


@pytest.fixture
def client():
    async def override_get_db():
        yield SimpleNamespace(name="test-db")

    async def override_get_current_user():
        return SimpleNamespace(id=123)

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _make_quiz(bank_id=10, time_spent=45, completion_time=45):
    return SimpleNamespace(
        id=55,
        bank_id=bank_id,
        score=50.0,
        completion_time_seconds=completion_time,
        time_spent_seconds=time_spent,
        total_questions=2,
        correct_answers=1,
        submitted_at=datetime(2026, 5, 18, 6, 0, tzinfo=timezone.utc),
        status="completed",
        created_at=datetime(2026, 5, 15, 12, 0, tzinfo=timezone.utc),
    )


def _make_results():
    return [
        QuizAnswerResult(
            question_id=101,
            selected_answer="A",
            correct_answer="A",
            is_correct=True,
        ),
        QuizAnswerResult(
            question_id=102,
            selected_answer="B",
            correct_answer="C",
            is_correct=False,
        ),
    ]


# ─────────────────────────────────────────────────────────────────────────────
# Existing tests (preserved)
# ─────────────────────────────────────────────────────────────────────────────

def test_submit_quiz_success(client, monkeypatch):
    captured = {}

    async def fake_grade_and_save(
        db,
        user_id,
        bank_id,
        answers,
        completion_time_seconds=None,
        time_spent_seconds=None,
    ):
        captured["db"] = db
        captured["user_id"] = user_id
        captured["bank_id"] = bank_id
        captured["answers"] = answers
        captured["completion_time_seconds"] = completion_time_seconds
        captured["time_spent_seconds"] = time_spent_seconds

        return _make_quiz(bank_id=bank_id, time_spent=completion_time_seconds, completion_time=completion_time_seconds), _make_results()

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "A"},
                {"question_id": 102, "selected_answer": "B"},
            ],
            "completion_time_seconds": 45,
        },
    )

    assert response.status_code == 201
    data = response.json()

    assert captured["user_id"] == 123
    assert captured["bank_id"] == 10
    assert captured["completion_time_seconds"] == 45
    assert [answer.question_id for answer in captured["answers"]] == [101, 102]
    assert [answer.selected_answer for answer in captured["answers"]] == ["A", "B"]

    assert data["quiz_id"] == 55
    assert data["bank_id"] == 10
    assert data["score"] == 50.0
    assert data["total_questions"] == 2
    assert data["correct_count"] == 1
    assert data["completion_time_seconds"] == 45
    assert data["status"] == "completed"
    assert data["results"] == [
        {
            "question_id": 101,
            "selected_answer": "A",
            "correct_answer": "A",
            "is_correct": True,
        },
        {
            "question_id": 102,
            "selected_answer": "B",
            "correct_answer": "C",
            "is_correct": False,
        },
    ]


def test_submit_quiz_bank_not_found(client, monkeypatch):
    async def fake_grade_and_save(
        db,
        user_id,
        bank_id,
        answers,
        completion_time_seconds=None,
        time_spent_seconds=None,
    ):
        raise ValueError("not_found:Question bank 999 not found")

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/999/submit",
        json={
            "answers": [{"question_id": 101, "selected_answer": "A"}],
            "completion_time_seconds": 45,
        },
    )

    assert response.status_code == 404
    assert "Question bank 999 not found" in response.json()["detail"]


def test_submit_quiz_rejects_invalid_completion_time(client):
    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [{"question_id": 101, "selected_answer": "A"}],
            "completion_time_seconds": -1,
        },
    )

    assert response.status_code == 422


# ─────────────────────────────────────────────────────────────────────────────
# New tests: time_spent_seconds
# ─────────────────────────────────────────────────────────────────────────────

def test_submit_accepts_time_spent_seconds(client, monkeypatch):
    """time_spent_seconds is the primary field and should be forwarded correctly."""
    captured = {}

    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        captured["time_spent_seconds"] = time_spent_seconds
        captured["completion_time_seconds"] = completion_time_seconds
        return _make_quiz(bank_id=bank_id, time_spent=time_spent_seconds, completion_time=completion_time_seconds), _make_results()

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "A"},
                {"question_id": 102, "selected_answer": "B"},
            ],
            "time_spent_seconds": 60,
        },
    )

    assert response.status_code == 201
    assert captured["time_spent_seconds"] == 60
    # completion_time_seconds should be back-filled by the schema validator
    assert captured["completion_time_seconds"] == 60


def test_submit_both_timing_fields_accepted(client, monkeypatch):
    """Both timing fields in same request should be accepted (time_spent takes precedence)."""
    captured = {}

    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        captured["time_spent_seconds"] = time_spent_seconds
        captured["completion_time_seconds"] = completion_time_seconds
        return _make_quiz(bank_id=bank_id, time_spent=time_spent_seconds, completion_time=completion_time_seconds), _make_results()

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "A"},
                {"question_id": 102, "selected_answer": "B"},
            ],
            "time_spent_seconds": 60,
            "completion_time_seconds": 45,
        },
    )

    assert response.status_code == 201
    assert captured["time_spent_seconds"] == 60


def test_submit_neither_timing_field_returns_422(client):
    """Omitting both timing fields should fail schema validation (422)."""
    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [{"question_id": 101, "selected_answer": "A"}],
            # no timing field
        },
    )
    assert response.status_code == 422


# ─────────────────────────────────────────────────────────────────────────────
# New tests: persisted fields in response
# ─────────────────────────────────────────────────────────────────────────────

def test_submit_response_includes_new_fields(client, monkeypatch):
    """Response should include correct_answers, time_spent_seconds, submitted_at."""
    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        return _make_quiz(bank_id=bank_id), _make_results()

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "A"},
                {"question_id": 102, "selected_answer": "B"},
            ],
            "time_spent_seconds": 45,
        },
    )

    assert response.status_code == 201
    data = response.json()
    # New fields
    assert "correct_answers" in data
    assert data["correct_answers"] == 1
    assert "time_spent_seconds" in data
    assert "submitted_at" in data
    # Backward-compat fields still present
    assert "correct_count" in data
    assert "completion_time_seconds" in data


# ─────────────────────────────────────────────────────────────────────────────
# New tests: 400 validation errors
# ─────────────────────────────────────────────────────────────────────────────

def test_missing_answers_returns_400(client, monkeypatch):
    """Repository raises bad_request → endpoint returns 400."""
    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        raise ValueError("bad_request:Missing answers for question IDs: [102]")

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [{"question_id": 101, "selected_answer": "A"}],
            "completion_time_seconds": 30,
        },
    )

    assert response.status_code == 400
    assert "Missing answers" in response.json()["detail"]


def test_duplicate_answers_returns_400(client, monkeypatch):
    """Duplicate question IDs in payload → 400."""
    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        raise ValueError("bad_request:Duplicate answers for question IDs: [101]")

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "A"},
                {"question_id": 101, "selected_answer": "B"},
            ],
            "completion_time_seconds": 30,
        },
    )

    assert response.status_code == 400
    assert "Duplicate answers" in response.json()["detail"]


def test_unknown_question_id_returns_400(client, monkeypatch):
    """Unknown question IDs in payload → 400."""
    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        raise ValueError("bad_request:Unknown question IDs for this bank: [999]")

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [{"question_id": 999, "selected_answer": "A"}],
            "completion_time_seconds": 30,
        },
    )

    assert response.status_code == 400
    assert "Unknown question IDs" in response.json()["detail"]


def test_completion_time_seconds_still_works(client, monkeypatch):
    """Existing clients sending only completion_time_seconds continue to work."""
    captured = {}

    async def fake_grade_and_save(
        db, user_id, bank_id, answers,
        completion_time_seconds=None, time_spent_seconds=None,
    ):
        captured["completion_time_seconds"] = completion_time_seconds
        captured["time_spent_seconds"] = time_spent_seconds
        return _make_quiz(bank_id=bank_id), _make_results()

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [
                {"question_id": 101, "selected_answer": "A"},
                {"question_id": 102, "selected_answer": "B"},
            ],
            "completion_time_seconds": 90,
        },
    )

    assert response.status_code == 201
    # Schema back-fills time_spent_seconds from completion_time_seconds
    assert captured["completion_time_seconds"] == 90
    assert captured["time_spent_seconds"] == 90
