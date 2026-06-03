from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
from types import SimpleNamespace
import sys

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("SECRET_KEY", "test-secret-key-for-sync-tests-123456789")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.api.v1.endpoints import sync as sync_endpoint  # noqa: E402
from app.core.database import get_db  # noqa: E402
from app.core.dependencies import get_current_user  # noqa: E402
from app.main import app  # noqa: E402
from app.models.learning import UserQuiz  # noqa: E402
from app.models.translation import (  # noqa: E402
    Translation,
    Vocabulary,
    VocabularyCategory,
)
from app.models.user import User  # noqa: E402
from app.schemas.sync import (  # noqa: E402
    FlashcardPushPayload,
    QuizAttemptPushPayload,
    SyncPullResponse,
    SyncPushItem,
    SyncPushResponse,
    SyncPushResultItem,
    SyncVocabularyResponse,
    SyncVocabularyResultItem,
)
from app.services.sync_service import (  # noqa: E402
    SyncCursorError,
    SyncItemError,
    SyncService,
    _build_conflict_info,
    _validate_client_timestamp,
    _MIN_VALID_TIMESTAMP,
    _MAX_FUTURE_DRIFT_SECONDS,
)


NOW = datetime(2026, 5, 31, 10, 0, tzinfo=timezone.utc)


class NestedTransaction:
    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        return False


class FakeDB:
    def __init__(self, results=None):
        self.results = iter(results or [])
        self.commit_count = 0
        self.flush_count = 0

    def begin_nested(self):
        return NestedTransaction()

    async def execute(self, stmt):
        return next(self.results)

    async def commit(self):
        self.commit_count += 1

    async def flush(self):
        self.flush_count += 1

    async def refresh(self, item):
        pass

    def add(self, item):
        pass


class FakeResult:
    def __init__(self, items):
        self.items = items

    def scalars(self):
        return self

    def all(self):
        return self.items

    def first(self):
        return self.items[0] if self.items else None


def _flashcard(card_id=10, updated_at=NOW, is_deleted=False):
    return Vocabulary(
        id=card_id,
        user_id=123,
        sync_client_id="flash-local",
        translation_id=99,
        category_id=None,
        category="General",
        word="hello",
        definition="xin chao",
        source_language="en",
        target_language="vi",
        mastery_level=1,
        is_deleted=is_deleted,
        created_at=NOW - timedelta(days=1),
        updated_at=updated_at,
    )


def _translation():
    return Translation(
        id=99,
        user_id=123,
        source_language="en",
        target_language="vi",
        source_text="hello",
        translated_text="xin chao",
        translation_type="text",
        is_deleted=False,
        created_at=NOW - timedelta(days=1),
        updated_at=NOW,
    )


def _quiz(quiz_id=20, updated_at=NOW):
    return UserQuiz(
        id=quiz_id,
        user_id=123,
        sync_client_id="quiz-local",
        bank_id=7,
        score=100.0,
        completion_time_seconds=30,
        time_spent_seconds=30,
        total_questions=1,
        correct_answers=1,
        submitted_at=NOW,
        status="completed",
        created_at=NOW,
        updated_at=updated_at,
    )


@pytest.mark.asyncio
async def test_push_isolates_failed_items(monkeypatch):
    db = FakeDB()

    async def fake_sync_flashcard(**kwargs):
        if kwargs["client_id"] == "bad":
            raise SyncItemError("invalid_category", "Unknown category")
        return SyncPushResultItem(
            resource="flashcard",
            client_id=kwargs["client_id"],
            server_id=10,
            status="created",
            server_updated_at=NOW,
            canonical={"id": 10},
        )

    monkeypatch.setattr(SyncService, "_sync_flashcard", fake_sync_flashcard)
    items = [
        SyncPushItem(
            resource="flashcard",
            client_id=client_id,
            updated_at=NOW,
            payload={
                "word": "hello",
                "translation": "xin chao",
                "source_language": "en",
                "target_language": "vi",
            },
        )
        for client_id in ("good", "bad")
    ]

    response = await SyncService.push(db=db, user_id=123, items=items)

    assert response.succeeded_count == 1
    assert response.failed_count == 1
    assert response.results[0].status == "created"
    assert response.results[1].status == "failed"
    assert response.results[1].error.code == "invalid_category"
    assert db.commit_count == 1


@pytest.mark.asyncio
async def test_flashcard_last_write_wins_updates_denormalized_translation(monkeypatch):
    db = FakeDB()
    vocabulary = _flashcard()
    translation = _translation()

    async def valid_category(db, user_id, category_id):
        return None

    async def existing_flashcard(**kwargs):
        return vocabulary, translation

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", existing_flashcard)

    # ---- client sends a stale (older) timestamp → server wins ----
    stale = await SyncService._sync_flashcard(
        db=db,
        user_id=123,
        client_id="flash-local",
        server_id=10,
        client_updated_at=NOW - timedelta(seconds=1),
        payload=FlashcardPushPayload(
            word="ignored",
            translation="ignored",
            source_language="en",
            target_language="vi",
        ),
        allow_content_match=False,
    )
    assert stale.status == "conflict_server_wins"
    assert stale.conflict is not None
    assert stale.conflict.winner == "server"
    assert vocabulary.word == "hello"  # data not changed

    # ---- client sends a newer timestamp → client wins ----
    updated = await SyncService._sync_flashcard(
        db=db,
        user_id=123,
        client_id="flash-local",
        server_id=10,
        client_updated_at=NOW + timedelta(seconds=1),
        payload=FlashcardPushPayload(
            word="hello updated",
            translation="xin chao updated",
            source_language="en",
            target_language="vi",
            mastery_level=4,
            is_deleted=True,
        ),
        allow_content_match=False,
    )
    assert updated.status == "conflict_client_wins"
    assert updated.conflict is not None
    assert updated.conflict.winner == "client"
    assert vocabulary.word == translation.source_text == "hello updated"
    assert vocabulary.definition == translation.translated_text == "xin chao updated"
    assert vocabulary.mastery_level == 4
    assert vocabulary.is_deleted is True
    assert translation.is_deleted is True


@pytest.mark.asyncio
async def test_flashcard_sync_resolves_auto_source_from_existing_translation(monkeypatch):
    db = FakeDB()
    vocabulary = _flashcard()
    translation = _translation()

    async def valid_category(db, user_id, category_id):
        return None

    async def existing_flashcard(**kwargs):
        return vocabulary, translation

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", existing_flashcard)

    result = await SyncService._sync_flashcard(
        db=db,
        user_id=123,
        client_id="flash-local",
        server_id=None,
        client_updated_at=NOW + timedelta(seconds=1),
        payload=FlashcardPushPayload(
            word="hello",
            translation="xin chao",
            source_language="auto",
            target_language="vi",
        ),
        allow_content_match=True,
    )

    assert result.status == "conflict_client_wins"
    assert vocabulary.source_language == "en"
    assert translation.source_language == "en"
    assert result.canonical["source_language"] == "en"


@pytest.mark.asyncio
async def test_flashcard_sync_rejects_unresolved_auto_source(monkeypatch):
    async def valid_category(db, user_id, category_id):
        return None

    async def no_existing(**kwargs):
        return None, None

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", no_existing)

    with pytest.raises(SyncItemError) as exc_info:
        await SyncService._sync_flashcard(
            db=FakeDB(),
            user_id=123,
            client_id="flash-auto",
            server_id=None,
            client_updated_at=NOW,
            payload=FlashcardPushPayload(
                word="hello",
                translation="xin chao",
                source_language="auto",
                target_language="vi",
            ),
            allow_content_match=True,
        )

    assert exc_info.value.code == "invalid_language"


@pytest.mark.asyncio
async def test_flashcard_push_retry_is_idempotent_with_database():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as connection:
        await connection.run_sync(
            lambda sync_connection: User.metadata.create_all(
                sync_connection,
                tables=[
                    User.__table__,
                    Translation.__table__,
                    VocabularyCategory.__table__,
                    Vocabulary.__table__,
                ],
            )
        )
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    item = SyncPushItem(
        resource="flashcard",
        client_id="stable-local-id",
        updated_at=datetime.now(timezone.utc) - timedelta(seconds=1),
        payload={
            "word": "hello",
            "translation": "xin chao",
            "source_language": "en",
            "target_language": "vi",
        },
    )

    async with async_session() as db:
        first = await SyncService.push(db=db, user_id=123, items=[item])
        second = await SyncService.push(db=db, user_id=123, items=[item])
        vocabulary_count = (
            await db.execute(select(func.count(Vocabulary.id)))
        ).scalar_one()
        translation_count = (
            await db.execute(select(func.count(Translation.id)))
        ).scalar_one()

    await engine.dispose()
    assert first.results[0].status == "created"
    assert second.results[0].status == "conflict_server_wins"
    assert second.results[0].server_id == first.results[0].server_id
    # conflict info must be present
    assert second.results[0].conflict is not None
    assert second.results[0].conflict.winner == "server"
    assert vocabulary_count == 1
    assert translation_count == 1


# ---------------------------------------------------------------------------
# NEW: Conflict resolution test cases
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_conflict_equal_timestamps_server_wins(monkeypatch):
    """When client and server have the same timestamp, server data must be retained."""
    db = FakeDB()
    vocabulary = _flashcard(updated_at=NOW)
    translation = _translation()

    async def valid_category(db, user_id, category_id):
        return None

    async def existing_flashcard(**kwargs):
        return vocabulary, translation

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", existing_flashcard)

    result = await SyncService._sync_flashcard(
        db=db,
        user_id=123,
        client_id="flash-local",
        server_id=10,
        client_updated_at=NOW,  # exactly equal
        payload=FlashcardPushPayload(
            word="attempt to overwrite",
            translation="ignored",
            source_language="en",
            target_language="vi",
        ),
        allow_content_match=False,
    )
    assert result.status == "conflict_server_wins"
    assert result.conflict is not None
    assert result.conflict.winner == "server"
    assert vocabulary.word == "hello"  # server data must not be overwritten


@pytest.mark.asyncio
async def test_invalid_timestamp_too_old_is_rejected(monkeypatch):
    """Timestamps before _MIN_VALID_TIMESTAMP must be rejected with invalid_timestamp."""
    db = FakeDB()

    async def valid_category(db, user_id, category_id):
        return None

    async def no_existing(**kwargs):
        return None, None

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", no_existing)

    too_old = _MIN_VALID_TIMESTAMP - timedelta(days=1)  # 2019-12-31
    with pytest.raises(SyncItemError) as exc_info:
        await SyncService._sync_flashcard(
            db=db,
            user_id=123,
            client_id="flash-old",
            server_id=None,
            client_updated_at=too_old,
            payload=FlashcardPushPayload(
                word="test",
                translation="test",
                source_language="en",
                target_language="vi",
            ),
            allow_content_match=False,
        )
    assert exc_info.value.code == "invalid_timestamp"


@pytest.mark.asyncio
async def test_invalid_timestamp_far_future_is_rejected(monkeypatch):
    """Timestamps more than MAX_FUTURE_DRIFT_SECONDS ahead of server must be rejected."""
    db = FakeDB()

    async def valid_category(db, user_id, category_id):
        return None

    async def no_existing(**kwargs):
        return None, None

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", no_existing)

    far_future = datetime.now(timezone.utc) + timedelta(seconds=_MAX_FUTURE_DRIFT_SECONDS + 60)
    with pytest.raises(SyncItemError) as exc_info:
        await SyncService._sync_flashcard(
            db=db,
            user_id=123,
            client_id="flash-future",
            server_id=None,
            client_updated_at=far_future,
            payload=FlashcardPushPayload(
                word="test",
                translation="test",
                source_language="en",
                target_language="vi",
            ),
            allow_content_match=False,
        )
    assert exc_info.value.code == "invalid_timestamp"


@pytest.mark.asyncio
async def test_conflict_is_logged_server_wins(monkeypatch, caplog):
    """A structured warning must be emitted when server wins the LWW conflict."""
    import logging

    db = FakeDB()
    vocabulary = _flashcard(updated_at=NOW)
    translation = _translation()

    async def valid_category(db, user_id, category_id):
        return None

    async def existing_flashcard(**kwargs):
        return vocabulary, translation

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", existing_flashcard)

    with caplog.at_level(logging.WARNING, logger="app.services.sync_service"):
        await SyncService._sync_flashcard(
            db=db,
            user_id=123,
            client_id="flash-local",
            server_id=10,
            client_updated_at=NOW - timedelta(seconds=5),
            payload=FlashcardPushPayload(
                word="ignored",
                translation="ignored",
                source_language="en",
                target_language="vi",
            ),
            allow_content_match=False,
        )

    assert any("server_wins" in record.message for record in caplog.records), (
        "Expected a 'server_wins' warning log entry for the LWW conflict"
    )


@pytest.mark.asyncio
async def test_conflict_is_logged_client_wins(monkeypatch, caplog):
    """A structured warning must be emitted when client wins the LWW conflict."""
    import logging

    db = FakeDB()
    vocabulary = _flashcard(updated_at=NOW)
    translation = _translation()

    async def valid_category(db, user_id, category_id):
        return None

    async def existing_flashcard(**kwargs):
        return vocabulary, translation

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", existing_flashcard)

    with caplog.at_level(logging.WARNING, logger="app.services.sync_service"):
        await SyncService._sync_flashcard(
            db=db,
            user_id=123,
            client_id="flash-local",
            server_id=10,
            client_updated_at=NOW + timedelta(seconds=5),
            payload=FlashcardPushPayload(
                word="newer word",
                translation="newer trans",
                source_language="en",
                target_language="vi",
            ),
            allow_content_match=False,
        )

    assert any("client_wins" in record.message for record in caplog.records), (
        "Expected a 'client_wins' warning log entry for the LWW conflict"
    )


@pytest.mark.asyncio
async def test_conflict_info_in_push_response_batch(monkeypatch):
    """End-to-end: push batch must surface conflict field in the result for conflicting items."""
    db = FakeDB()
    vocabulary = _flashcard(updated_at=NOW)
    translation = _translation()

    async def valid_category(db, user_id, category_id):
        return None

    async def existing_flashcard(**kwargs):
        return vocabulary, translation

    monkeypatch.setattr(SyncService, "_validate_category", valid_category)
    monkeypatch.setattr(SyncService, "_find_flashcard", existing_flashcard)

    # Stale item → server wins
    stale_item = SyncPushItem(
        resource="flashcard",
        client_id="flash-local",
        updated_at=NOW - timedelta(seconds=10),
        payload={
            "word": "old word",
            "translation": "old trans",
            "source_language": "en",
            "target_language": "vi",
        },
    )
    response = await SyncService.push(db=db, user_id=123, items=[stale_item])

    assert response.results[0].status == "conflict_server_wins"
    assert response.results[0].conflict is not None
    assert response.results[0].conflict.conflict_type == "timestamp_conflict"
    assert response.results[0].conflict.winner == "server"
    assert response.results[0].canonical is not None  # server data returned


def test_validate_client_timestamp_accepts_valid():
    """Valid timestamps within range must pass without raising."""
    valid_ts = datetime.now(timezone.utc) - timedelta(hours=1)
    result = _validate_client_timestamp(valid_ts)
    assert result.tzinfo is not None  # must be UTC-aware


def test_validate_client_timestamp_rejects_none():
    with pytest.raises(SyncItemError) as exc_info:
        _validate_client_timestamp(None)
    assert exc_info.value.code == "invalid_timestamp"


def test_build_conflict_info_server_wins():
    """_build_conflict_info must set winner and include both timestamps."""
    client_ts = NOW - timedelta(seconds=10)
    server_ts = NOW
    info = _build_conflict_info(client_ts, server_ts, "server")
    assert info.winner == "server"
    assert "server" in info.reason.lower()
    assert info.client_updated_at == client_ts
    assert info.server_updated_at == server_ts


def test_build_conflict_info_client_wins():
    """_build_conflict_info must set winner and include both timestamps."""
    client_ts = NOW + timedelta(seconds=10)
    server_ts = NOW
    info = _build_conflict_info(client_ts, server_ts, "client")
    assert info.winner == "client"
    assert "client" in info.reason.lower()


@pytest.mark.asyncio
async def test_quiz_attempt_retry_is_immutable(monkeypatch):
    existing = _quiz()

    async def find_existing(db, user_id, client_id, server_id):
        return existing

    async def should_not_grade(**kwargs):
        raise AssertionError("Retry must not grade or insert a second attempt")

    monkeypatch.setattr(SyncService, "_find_quiz_attempt", find_existing)
    monkeypatch.setattr("app.services.sync_service.QuizRepository.grade_and_save", should_not_grade)

    result = await SyncService._sync_quiz_attempt(
        db=FakeDB(),
        user_id=123,
        client_id="quiz-local",
        server_id=None,
        payload=QuizAttemptPushPayload(
            bank_id=7,
            answers=[{"question_id": 1, "selected_answer": "A"}],
            time_spent_seconds=30,
        ),
    )
    assert result.status == "unchanged"
    assert result.canonical["score"] == 100.0


@pytest.mark.asyncio
async def test_new_quiz_attempt_delegates_server_side_grading(monkeypatch):
    captured = {}

    async def find_none(db, user_id, client_id, server_id):
        return None

    async def grade_and_save(**kwargs):
        captured.update(kwargs)
        return _quiz(), []

    monkeypatch.setattr(SyncService, "_find_quiz_attempt", find_none)
    monkeypatch.setattr("app.services.sync_service.QuizRepository.grade_and_save", grade_and_save)

    result = await SyncService._sync_quiz_attempt(
        db=FakeDB(),
        user_id=123,
        client_id="quiz-local",
        server_id=None,
        payload=QuizAttemptPushPayload(
            bank_id=7,
            answers=[{"question_id": 1, "selected_answer": "A"}],
            time_spent_seconds=30,
        ),
    )
    assert result.status == "created"
    assert captured["commit"] is False
    assert captured["sync_client_id"] == "quiz-local"
    assert captured["answers"][0].selected_answer == "A"


@pytest.mark.asyncio
async def test_new_quiz_attempt_allows_empty_answers_for_submit_and_exit(monkeypatch):
    captured = {}

    async def find_none(db, user_id, client_id, server_id):
        return None

    async def grade_and_save(**kwargs):
        captured.update(kwargs)
        return _quiz(quiz_id=21), []

    monkeypatch.setattr(SyncService, "_find_quiz_attempt", find_none)
    monkeypatch.setattr("app.services.sync_service.QuizRepository.grade_and_save", grade_and_save)

    result = await SyncService._sync_quiz_attempt(
        db=FakeDB(),
        user_id=123,
        client_id="quiz-empty",
        server_id=None,
        payload=QuizAttemptPushPayload(
            bank_id=7,
            answers=[],
            time_spent_seconds=12,
        ),
    )

    assert result.status == "created"
    assert captured["answers"] == []
    assert captured["time_spent_seconds"] == 12


@pytest.mark.asyncio
async def test_pull_returns_sorted_snapshot_page_and_tombstone():
    tombstone = _flashcard(card_id=1, is_deleted=True)
    first_quiz = _quiz(quiz_id=2)
    second_quiz = _quiz(quiz_id=3)
    db = FakeDB(
        results=[
            FakeResult([tombstone]),
            FakeResult([(first_quiz, "Basics"), (second_quiz, "Basics")]),
        ]
    )

    response = await SyncService.pull(db=db, user_id=123, cursor=None, limit=2)

    assert response.has_more is True
    assert [(item.resource, item.server_id) for item in response.items] == [
        ("flashcard", 1),
        ("quiz_attempt", 2),
    ]
    assert response.items[0].payload["is_deleted"] is True
    assert "correct_answer" not in response.items[1].payload
    cursor_state = SyncService._decode_cursor(response.next_cursor)
    assert cursor_state["position"]["resource"] == "quiz_attempt"
    assert cursor_state["position"]["id"] == 2
    assert cursor_state["cutoff"]


def test_cursor_rejects_tampering():
    cursor = SyncService._encode_cursor(
        {"v": 1, "since": "2026-05-31T10:00:00+00:00"}
    )
    with pytest.raises(SyncCursorError):
        SyncService._decode_cursor(f"{cursor}tampered")


def test_cursor_rejects_malformed_payload():
    with pytest.raises(SyncCursorError):
        SyncService._decode_cursor("not-base64.not-base64")


def test_sync_endpoints_expose_push_pull_and_keep_legacy(monkeypatch):
    async def override_get_db():
        yield SimpleNamespace(name="test-db")

    async def override_get_current_user():
        return SimpleNamespace(id=123)

    async def fake_push(db, user_id, items):
        return SyncPushResponse(succeeded_count=1, failed_count=0, results=[
            SyncPushResultItem(
                resource="flashcard",
                client_id="local-1",
                server_id=10,
                status="created",
                server_updated_at=NOW,
                canonical={"id": 10},
            )
        ])

    async def fake_pull(db, user_id, cursor, limit):
        return SyncPullResponse(items=[], next_cursor="cursor", has_more=False)

    async def fake_legacy(db, user_id, items):
        return SyncVocabularyResponse(
            synced_count=1,
            results=[
                SyncVocabularyResultItem(
                    client_id="local-1",
                    server_id=10,
                    status="created",
                    server_updated_at=NOW,
                )
            ],
        )

    async def fake_broadcast(user_id, synced_count):
        pass

    monkeypatch.setattr(SyncService, "push", fake_push)
    monkeypatch.setattr(SyncService, "pull", fake_pull)
    monkeypatch.setattr(SyncService, "sync_vocabulary", fake_legacy)
    monkeypatch.setattr(sync_endpoint, "_broadcast_sync_completed", fake_broadcast)
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user
    client = TestClient(app)

    try:
        push_response = client.post(
            "/api/v1/sync/push",
            json={
                "items": [{
                    "resource": "flashcard",
                    "client_id": "local-1",
                    "updated_at": NOW.isoformat(),
                    "payload": {
                        "word": "hello",
                        "translation": "xin chao",
                        "source_language": "en",
                        "target_language": "vi",
                    },
                }]
            },
        )
        pull_response = client.get("/api/v1/sync/pull")
        legacy_response = client.post(
            "/api/v1/sync/vocabulary",
            json={
                "items": [{
                    "client_id": "local-1",
                    "word": "hello",
                    "translation": "xin chao",
                    "source_language": "en",
                    "target_language": "vi",
                    "created_at": NOW.isoformat(),
                    "updated_at": NOW.isoformat(),
                }]
            },
        )

        assert push_response.status_code == 200
        assert push_response.json()["succeeded_count"] == 1
        assert pull_response.status_code == 200
        assert pull_response.json()["next_cursor"] == "cursor"
        assert legacy_response.status_code == 200
        assert legacy_response.json()["data"]["synced_count"] == 1
        paths = {route.path for route in app.routes}
        assert "/api/v1/sync/vocabulary" in paths
    finally:
        app.dependency_overrides.clear()
