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


def test_submit_quiz_success(client, monkeypatch):
    captured = {}

    async def fake_grade_and_save(
        db,
        user_id,
        bank_id,
        answers,
        completion_time_seconds,
    ):
        captured["db"] = db
        captured["user_id"] = user_id
        captured["bank_id"] = bank_id
        captured["answers"] = answers
        captured["completion_time_seconds"] = completion_time_seconds

        quiz = SimpleNamespace(
            id=55,
            bank_id=bank_id,
            score=50.0,
            completion_time_seconds=completion_time_seconds,
            status="completed",
            created_at=datetime(2026, 5, 15, 12, 0, tzinfo=timezone.utc),
        )
        results = [
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
        return quiz, results

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
        completion_time_seconds,
    ):
        raise ValueError("Question bank 999 not found")

    monkeypatch.setattr(QuizRepository, "grade_and_save", fake_grade_and_save)

    response = client.post(
        "/api/v1/learning/banks/999/submit",
        json={
            "answers": [{"question_id": 101, "selected_answer": "A"}],
            "completion_time_seconds": 45,
        },
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Question bank 999 not found"


def test_submit_quiz_rejects_invalid_completion_time(client):
    response = client.post(
        "/api/v1/learning/banks/10/submit",
        json={
            "answers": [{"question_id": 101, "selected_answer": "A"}],
            "completion_time_seconds": -1,
        },
    )

    assert response.status_code == 422
