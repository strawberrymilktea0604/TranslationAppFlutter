"""Business logic for offline-first flashcard and quiz synchronization."""
import base64
import binascii
import hashlib
import hmac
import json
import logging
import random
import time
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from pydantic import ValidationError
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.learning import QuestionBank, UserQuiz
from app.models.translation import Translation, Vocabulary, VocabularyCategory
from app.repositories.quiz_repository import QuizRepository
from app.schemas.learning import UserAnswerItem
from app.schemas.sync import (
    ConflictInfo,
    FlashcardPushPayload,
    QuizAttemptPushPayload,
    SyncError,
    SyncPullItem,
    SyncPullResponse,
    SyncPushItem,
    SyncPushResponse,
    SyncPushResultItem,
    SyncVocabularyFailureItem,
    SyncVocabularyItem,
    SyncVocabularyResponse,
    SyncVocabularyResultItem,
)

logger = logging.getLogger(__name__)
_CURSOR_VERSION = 1
_INITIAL_SYNC_TIME = datetime(1970, 1, 1, tzinfo=timezone.utc)

# ---------------------------------------------------------------------------
# Timestamp validation constants for LWW conflict resolution
# ---------------------------------------------------------------------------
# Timestamps older than this are almost certainly device clock errors or
# default values from uninitialized clients — reject them outright.
_MIN_VALID_TIMESTAMP: datetime = datetime(2020, 1, 1, tzinfo=timezone.utc)

# Allow client clocks to be at most this many seconds ahead of server time.
# Rejects malicious or badly-drifted clocks that could silently win every
# conflict by sending timestamps far in the future.
_MAX_FUTURE_DRIFT_SECONDS: int = 300  # 5 minutes



class SyncItemError(Exception):
    """A client-correctable error for one item in a push batch."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


class SyncCursorError(ValueError):
    """Raised when a pull cursor is malformed or has an invalid signature."""


def _generate_snowflake_id() -> int:
    return (int(time.time() * 1000) << 22) | random.randint(0, 4194303)


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _isoformat(value: datetime) -> str:
    return _as_utc(value).isoformat()


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _b64decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def _validate_client_timestamp(client_updated_at: Optional[datetime]) -> datetime:
    """Return the UTC-normalised timestamp or raise SyncItemError.

    Guards:
    - None / missing value.
    - Timestamps older than _MIN_VALID_TIMESTAMP (epoch/uninitialised clocks).
    - Timestamps more than _MAX_FUTURE_DRIFT_SECONDS ahead of server time
      (malicious or severely drifted clocks that would always win LWW).
    """
    if client_updated_at is None:
        raise SyncItemError(
            "invalid_timestamp",
            "updated_at is required for sync push",
        )
    utc_ts = _as_utc(client_updated_at)
    if utc_ts < _MIN_VALID_TIMESTAMP:
        raise SyncItemError(
            "invalid_timestamp",
            f"updated_at {utc_ts.isoformat()} is before the minimum valid date "
            f"{_MIN_VALID_TIMESTAMP.isoformat()}. Check device clock.",
        )
    server_now = datetime.now(timezone.utc)
    if utc_ts > server_now.replace(microsecond=0) + timedelta(seconds=_MAX_FUTURE_DRIFT_SECONDS):
        raise SyncItemError(
            "invalid_timestamp",
            f"updated_at {utc_ts.isoformat()} is more than "
            f"{_MAX_FUTURE_DRIFT_SECONDS}s ahead of server time "
            f"{server_now.isoformat()}. Check device clock.",
        )
    return utc_ts


def _build_conflict_info(
    client_updated_at: datetime,
    server_updated_at: datetime,
    winner: str,
) -> ConflictInfo:
    """Construct a ConflictInfo describing the LWW resolution outcome."""
    utc_client = _as_utc(client_updated_at)
    utc_server = _as_utc(server_updated_at)
    delta_ms = int((utc_client - utc_server).total_seconds() * 1000)
    if winner == "client":
        reason = (
            f"Client timestamp is {delta_ms}ms newer than server "
            f"({utc_client.isoformat()} > {utc_server.isoformat()}). "
            "Client data applied."
        )
    else:
        reason = (
            f"Server timestamp is newer or equal "
            f"(client={utc_client.isoformat()}, server={utc_server.isoformat()}, "
            f"delta={delta_ms}ms). Server data retained."
        )
    return ConflictInfo(
        client_updated_at=utc_client,
        server_updated_at=utc_server,
        winner=winner,  # type: ignore[arg-type]
        reason=reason,
    )


class SyncService:
    """Coordinates legacy pushes, resource pushes, and delta pulls."""

    @staticmethod
    async def sync_vocabulary(
        db: AsyncSession,
        user_id: int,
        items: list[SyncVocabularyItem],
    ) -> SyncVocabularyResponse:
        """Keep the legacy vocabulary API working with additive failures."""
        results: list[SyncVocabularyResultItem] = []
        failures: list[SyncVocabularyFailureItem] = []

        for item in items:
            payload = FlashcardPushPayload(
                word=item.word,
                translation=item.translation,
                source_language=item.source_language,
                target_language=item.target_language,
                category_id=item.category_id,
                category=item.category,
                mastery_level=item.mastery_level,
                last_tested_at=item.last_tested_at,
                is_deleted=item.is_deleted,
                created_at=item.created_at,
            )
            try:
                async with db.begin_nested():
                    push_result = await SyncService._sync_flashcard(
                        db=db,
                        user_id=user_id,
                        client_id=item.client_id,
                        server_id=None,
                        client_updated_at=item.updated_at,
                        payload=payload,
                        allow_content_match=True,
                    )
                results.append(
                    SyncVocabularyResultItem(
                        client_id=item.client_id,
                        server_id=push_result.server_id,
                        status=push_result.status,
                        server_updated_at=push_result.server_updated_at,
                        canonical=push_result.canonical,
                    )
                )
            except Exception as exc:
                error = SyncService._to_sync_error(exc)
                failures.append(
                    SyncVocabularyFailureItem(client_id=item.client_id, error=error)
                )
                logger.warning("Legacy vocabulary sync failed for %s: %s", item.client_id, exc)

        await db.commit()
        synced_count = sum(1 for item in results if item.status in ("created", "updated"))
        return SyncVocabularyResponse(
            synced_count=synced_count,
            failed_count=len(failures),
            results=results,
            failures=failures,
        )

    @staticmethod
    async def push(
        db: AsyncSession,
        user_id: int,
        items: list[SyncPushItem],
    ) -> SyncPushResponse:
        """Push a mixed batch while isolating failures with savepoints."""
        results: list[SyncPushResultItem] = []

        for item in items:
            try:
                async with db.begin_nested():
                    if item.resource == "flashcard":
                        payload = FlashcardPushPayload.model_validate(item.payload)
                        result = await SyncService._sync_flashcard(
                            db=db,
                            user_id=user_id,
                            client_id=item.client_id,
                            server_id=item.server_id,
                            client_updated_at=item.updated_at,
                            payload=payload,
                            allow_content_match=True,
                        )
                    else:
                        payload = QuizAttemptPushPayload.model_validate(item.payload)
                        result = await SyncService._sync_quiz_attempt(
                            db=db,
                            user_id=user_id,
                            client_id=item.client_id,
                            server_id=item.server_id,
                            payload=payload,
                        )
                results.append(result)
            except Exception as exc:
                logger.warning(
                    "Push sync failed for resource=%s client_id=%s: %s",
                    item.resource,
                    item.client_id,
                    exc,
                )
                results.append(
                    SyncPushResultItem(
                        resource=item.resource,
                        client_id=item.client_id,
                        server_id=item.server_id,
                        status="failed",
                        error=SyncService._to_sync_error(exc),
                    )
                )

        await db.commit()
        failed_count = sum(1 for item in results if item.status == "failed")
        return SyncPushResponse(
            succeeded_count=len(results) - failed_count,
            failed_count=failed_count,
            results=results,
        )

    @staticmethod
    async def pull(
        db: AsyncSession,
        user_id: int,
        cursor: Optional[str],
        limit: int,
    ) -> SyncPullResponse:
        """Return a stable page of changes ordered by updated_at, resource, and ID."""
        state = SyncService._decode_cursor(cursor)
        since = _as_utc(datetime.fromisoformat(state["since"]))
        cutoff = _as_utc(
            datetime.fromisoformat(state["cutoff"])
            if state.get("cutoff")
            else datetime.now(timezone.utc)
        )
        position = state.get("position")

        vocab_stmt = (
            select(Vocabulary)
            .where(
                Vocabulary.user_id == user_id,
                Vocabulary.updated_at > since,
                Vocabulary.updated_at <= cutoff,
                SyncService._after_position(
                    Vocabulary.updated_at,
                    Vocabulary.id,
                    "flashcard",
                    position,
                ),
            )
            .order_by(Vocabulary.updated_at, Vocabulary.id)
            .limit(limit + 1)
        )
        quiz_stmt = (
            select(UserQuiz, QuestionBank.title)
            .join(QuestionBank, UserQuiz.bank_id == QuestionBank.id)
            .where(
                UserQuiz.user_id == user_id,
                UserQuiz.updated_at > since,
                UserQuiz.updated_at <= cutoff,
                SyncService._after_position(
                    UserQuiz.updated_at,
                    UserQuiz.id,
                    "quiz_attempt",
                    position,
                ),
            )
            .order_by(UserQuiz.updated_at, UserQuiz.id)
            .limit(limit + 1)
        )

        vocabularies = (await db.execute(vocab_stmt)).scalars().all()
        quizzes = (await db.execute(quiz_stmt)).all()
        changes = [
            SyncService._flashcard_pull_item(vocabulary) for vocabulary in vocabularies
        ]
        changes.extend(
            SyncService._quiz_pull_item(quiz, bank_title) for quiz, bank_title in quizzes
        )
        changes.sort(key=lambda item: (_as_utc(item.updated_at), item.resource, item.server_id))

        has_more = len(changes) > limit
        page = changes[:limit]
        if has_more:
            last = page[-1]
            next_state = {
                "v": _CURSOR_VERSION,
                "since": _isoformat(since),
                "cutoff": _isoformat(cutoff),
                "position": {
                    "updated_at": _isoformat(last.updated_at),
                    "resource": last.resource,
                    "id": last.server_id,
                },
            }
        else:
            next_state = {"v": _CURSOR_VERSION, "since": _isoformat(cutoff)}

        return SyncPullResponse(
            items=page,
            next_cursor=SyncService._encode_cursor(next_state),
            has_more=has_more,
        )

    @staticmethod
    async def _sync_flashcard(
        db: AsyncSession,
        user_id: int,
        client_id: str,
        server_id: Optional[int],
        client_updated_at: datetime,
        payload: FlashcardPushPayload,
        allow_content_match: bool,
    ) -> SyncPushResultItem:
        # ------------------------------------------------------------------
        # 1. Validate client timestamp before any DB work
        # ------------------------------------------------------------------
        utc_client_ts = _validate_client_timestamp(client_updated_at)

        safe_category_id = await SyncService._validate_category(
            db, user_id, payload.category_id
        )
        vocabulary, translation = await SyncService._find_flashcard(
            db=db,
            user_id=user_id,
            client_id=client_id,
            server_id=server_id,
            payload=payload,
            allow_content_match=allow_content_match,
        )
        if SyncService._is_auto_language(payload.source_language):
            if (
                translation is not None
                and translation.source_language
                and not SyncService._is_auto_language(translation.source_language)
            ):
                payload.source_language = translation.source_language
            else:
                raise SyncItemError(
                    "invalid_language",
                    "Flashcard source_language must be resolved before sync",
                )

        # ------------------------------------------------------------------
        # 2. New record — no conflict possible
        # ------------------------------------------------------------------
        if vocabulary is None:
            now = datetime.now(timezone.utc)
            if translation is None:
                translation = Translation(
                    id=_generate_snowflake_id(),
                    user_id=user_id,
                    source_language=payload.source_language,
                    target_language=payload.target_language,
                    source_text=payload.word,
                    translated_text=payload.translation,
                    translation_type="text",
                    is_deleted=payload.is_deleted,
                    created_at=payload.created_at or now,
                    updated_at=now,
                )
                db.add(translation)
                await db.flush()

            vocabulary = Vocabulary(
                id=_generate_snowflake_id(),
                user_id=user_id,
                sync_client_id=client_id,
                translation_id=translation.id,
                category_id=safe_category_id,
                category=payload.category,
                word=payload.word,
                definition=payload.translation,
                source_language=payload.source_language,
                target_language=payload.target_language,
                mastery_level=payload.mastery_level,
                last_tested_at=payload.last_tested_at,
                is_deleted=payload.is_deleted,
                created_at=payload.created_at or now,
                updated_at=now,
            )
            db.add(vocabulary)
            await db.flush()
            return SyncService._flashcard_push_result(client_id, "created", vocabulary)

        # ------------------------------------------------------------------
        # 3. Existing record — LWW conflict resolution
        # ------------------------------------------------------------------
        utc_server_ts = _as_utc(vocabulary.updated_at)

        if utc_client_ts <= utc_server_ts:
            # Server wins: client sent an older (or equal) timestamp.
            conflict = _build_conflict_info(utc_client_ts, utc_server_ts, "server")
            logger.warning(
                "LWW conflict resolved: server_wins | "
                "user_id=%s client_id=%s server_id=%s "
                "client_ts=%s server_ts=%s reason=%s",
                user_id,
                client_id,
                vocabulary.id,
                utc_client_ts.isoformat(),
                utc_server_ts.isoformat(),
                conflict.reason,
            )
            return SyncService._flashcard_push_result(
                client_id, "conflict_server_wins", vocabulary, conflict=conflict
            )

        # Client wins: client sent a newer timestamp — apply its data.
        conflict = _build_conflict_info(utc_client_ts, utc_server_ts, "client")
        logger.warning(
            "LWW conflict resolved: client_wins | "
            "user_id=%s client_id=%s server_id=%s "
            "client_ts=%s server_ts=%s reason=%s",
            user_id,
            client_id,
            vocabulary.id,
            utc_client_ts.isoformat(),
            utc_server_ts.isoformat(),
            conflict.reason,
        )

        now = datetime.now(timezone.utc)
        if vocabulary.sync_client_id is None:
            vocabulary.sync_client_id = client_id
        vocabulary.category_id = safe_category_id
        vocabulary.category = payload.category
        vocabulary.word = payload.word
        vocabulary.definition = payload.translation
        vocabulary.source_language = payload.source_language
        vocabulary.target_language = payload.target_language
        vocabulary.mastery_level = payload.mastery_level
        vocabulary.last_tested_at = payload.last_tested_at
        vocabulary.is_deleted = payload.is_deleted
        vocabulary.updated_at = now

        translation.source_text = payload.word
        translation.translated_text = payload.translation
        translation.source_language = payload.source_language
        translation.target_language = payload.target_language
        translation.is_deleted = payload.is_deleted
        translation.updated_at = now
        await db.flush()
        return SyncService._flashcard_push_result(
            client_id, "conflict_client_wins", vocabulary, conflict=conflict
        )

    @staticmethod
    async def _sync_quiz_attempt(
        db: AsyncSession,
        user_id: int,
        client_id: str,
        server_id: Optional[int],
        payload: QuizAttemptPushPayload,
    ) -> SyncPushResultItem:
        existing = await SyncService._find_quiz_attempt(db, user_id, client_id, server_id)
        if existing is not None:
            return SyncService._quiz_push_result(client_id, "unchanged", existing)

        answers = [
            UserAnswerItem(
                question_id=answer.question_id,
                selected_answer=answer.selected_answer,
            )
            for answer in payload.answers
        ]
        quiz, _ = await QuizRepository.grade_and_save(
            db=db,
            user_id=user_id,
            bank_id=payload.bank_id,
            answers=answers,
            time_spent_seconds=payload.time_spent_seconds,
            sync_client_id=client_id,
            commit=False,
        )
        if payload.created_at is not None:
            quiz.created_at = payload.created_at
        return SyncService._quiz_push_result(client_id, "created", quiz)

    @staticmethod
    async def _validate_category(
        db: AsyncSession,
        user_id: int,
        category_id: Optional[int],
    ) -> Optional[int]:
        if category_id is None or category_id <= 0:
            return None
        category = (
            await db.execute(
                select(VocabularyCategory.id).where(
                    VocabularyCategory.id == category_id,
                    VocabularyCategory.user_id == user_id,
                )
            )
        ).scalar_one_or_none()
        if category is None:
            raise SyncItemError("invalid_category", "Flashcard category does not exist")
        return category_id

    @staticmethod
    async def _find_flashcard(
        db: AsyncSession,
        user_id: int,
        client_id: str,
        server_id: Optional[int],
        payload: FlashcardPushPayload,
        allow_content_match: bool,
    ) -> tuple[Optional[Vocabulary], Optional[Translation]]:
        if server_id is not None:
            row = await SyncService._flashcard_row_by(db, user_id, Vocabulary.id == server_id)
            if row is None:
                raise SyncItemError("not_found", "Flashcard does not exist")
            return row

        row = await SyncService._flashcard_row_by(
            db, user_id, Vocabulary.sync_client_id == client_id
        )
        if row is not None:
            return row

        if client_id.isdigit():
            row = await SyncService._flashcard_row_by(
                db, user_id, Vocabulary.id == int(client_id)
            )
            if row is not None:
                return row

        if not allow_content_match:
            return None, None

        filters = [
            Translation.user_id == user_id,
            Translation.source_text == payload.word,
            Translation.translated_text == payload.translation,
            Translation.target_language == payload.target_language,
        ]
        if not SyncService._is_auto_language(payload.source_language):
            filters.append(Translation.source_language == payload.source_language)

        result = await db.execute(
            select(Translation, Vocabulary)
            .outerjoin(
                Vocabulary,
                and_(
                    Vocabulary.translation_id == Translation.id,
                    Vocabulary.user_id == user_id,
                ),
            )
            .where(*filters)
        )
        row = result.first()
        if row is None:
            return None, None
        translation, vocabulary = row
        return vocabulary, translation

    @staticmethod
    def _is_auto_language(language: Optional[str]) -> bool:
        return str(language or "").strip().lower() == "auto"

    @staticmethod
    async def _flashcard_row_by(
        db: AsyncSession,
        user_id: int,
        condition: Any,
    ) -> Optional[tuple[Vocabulary, Translation]]:
        result = await db.execute(
            select(Vocabulary, Translation)
            .join(Translation, Vocabulary.translation_id == Translation.id)
            .where(Vocabulary.user_id == user_id, condition)
        )
        return result.first()

    @staticmethod
    async def _find_quiz_attempt(
        db: AsyncSession,
        user_id: int,
        client_id: str,
        server_id: Optional[int],
    ) -> Optional[UserQuiz]:
        if server_id is not None:
            quiz = (
                await db.execute(
                    select(UserQuiz).where(
                        UserQuiz.id == server_id,
                        UserQuiz.user_id == user_id,
                    )
                )
            ).scalar_one_or_none()
            if quiz is None:
                raise SyncItemError("not_found", "Quiz attempt does not exist")
            return quiz

        quiz = (
            await db.execute(
                select(UserQuiz).where(
                    UserQuiz.user_id == user_id,
                    UserQuiz.sync_client_id == client_id,
                )
            )
        ).scalar_one_or_none()
        if quiz is not None:
            return quiz

        if client_id.isdigit():
            return (
                await db.execute(
                    select(UserQuiz).where(
                        UserQuiz.id == int(client_id),
                        UserQuiz.user_id == user_id,
                    )
                )
            ).scalar_one_or_none()
        return None

    @staticmethod
    def _flashcard_push_result(
        client_id: str,
        status: str,
        vocabulary: Vocabulary,
        conflict: Optional[ConflictInfo] = None,
    ) -> SyncPushResultItem:
        return SyncPushResultItem(
            resource="flashcard",
            client_id=client_id,
            server_id=vocabulary.id,
            status=status,
            server_updated_at=vocabulary.updated_at,
            canonical=SyncService._flashcard_payload(vocabulary),
            conflict=conflict,
        )

    @staticmethod
    def _quiz_push_result(
        client_id: str,
        status: str,
        quiz: UserQuiz,
    ) -> SyncPushResultItem:
        return SyncPushResultItem(
            resource="quiz_attempt",
            client_id=client_id,
            server_id=quiz.id,
            status=status,
            server_updated_at=quiz.updated_at,
            canonical=SyncService._quiz_payload(quiz),
        )

    @staticmethod
    def _flashcard_pull_item(vocabulary: Vocabulary) -> SyncPullItem:
        return SyncPullItem(
            resource="flashcard",
            server_id=vocabulary.id,
            updated_at=vocabulary.updated_at,
            payload=SyncService._flashcard_payload(vocabulary),
        )

    @staticmethod
    def _quiz_pull_item(quiz: UserQuiz, bank_title: str) -> SyncPullItem:
        return SyncPullItem(
            resource="quiz_attempt",
            server_id=quiz.id,
            updated_at=quiz.updated_at,
            payload=SyncService._quiz_payload(quiz, bank_title),
        )

    @staticmethod
    def _flashcard_payload(vocabulary: Vocabulary) -> dict[str, Any]:
        return {
            "id": vocabulary.id,
            "client_id": vocabulary.sync_client_id,
            "translation_id": vocabulary.translation_id,
            "word": vocabulary.word,
            "translation": vocabulary.definition,
            "source_language": vocabulary.source_language,
            "target_language": vocabulary.target_language,
            "category_id": vocabulary.category_id,
            "category": vocabulary.category,
            "mastery_level": vocabulary.mastery_level or 0,
            "last_tested_at": vocabulary.last_tested_at,
            "is_deleted": bool(vocabulary.is_deleted),
            "created_at": vocabulary.created_at,
            "updated_at": vocabulary.updated_at,
        }

    @staticmethod
    def _quiz_payload(quiz: UserQuiz, bank_title: Optional[str] = None) -> dict[str, Any]:
        return {
            "quiz_id": quiz.id,
            "client_id": quiz.sync_client_id,
            "bank_id": quiz.bank_id,
            "bank_title": bank_title,
            "score": quiz.score,
            "completion_time_seconds": quiz.completion_time_seconds,
            "time_spent_seconds": quiz.time_spent_seconds,
            "total_questions": quiz.total_questions,
            "correct_count": quiz.correct_answers,
            "correct_answers": quiz.correct_answers,
            "submitted_at": quiz.submitted_at,
            "status": quiz.status,
            "created_at": quiz.created_at,
            "updated_at": quiz.updated_at,
        }

    @staticmethod
    def _after_position(updated_at: Any, item_id: Any, resource: str, position: Any) -> Any:
        if position is None:
            return True

        position_time = _as_utc(datetime.fromisoformat(position["updated_at"]))
        position_resource = position["resource"]
        position_id = int(position["id"])
        if resource > position_resource:
            return or_(updated_at > position_time, updated_at == position_time)
        if resource == position_resource:
            return or_(
                updated_at > position_time,
                and_(updated_at == position_time, item_id > position_id),
            )
        return updated_at > position_time

    @staticmethod
    def _encode_cursor(state: dict[str, Any]) -> str:
        payload = json.dumps(state, separators=(",", ":"), sort_keys=True).encode("utf-8")
        signature = hmac.new(
            settings.SECRET_KEY.encode("utf-8"),
            payload,
            hashlib.sha256,
        ).digest()
        return f"{_b64encode(payload)}.{_b64encode(signature)}"

    @staticmethod
    def _decode_cursor(cursor: Optional[str]) -> dict[str, Any]:
        if cursor is None:
            return {"v": _CURSOR_VERSION, "since": _isoformat(_INITIAL_SYNC_TIME)}
        try:
            encoded_payload, encoded_signature = cursor.split(".", maxsplit=1)
            payload = _b64decode(encoded_payload)
            signature = _b64decode(encoded_signature)
            expected = hmac.new(
                settings.SECRET_KEY.encode("utf-8"),
                payload,
                hashlib.sha256,
            ).digest()
            if not hmac.compare_digest(signature, expected):
                raise SyncCursorError("Invalid sync cursor signature")
            state = json.loads(payload.decode("utf-8"))
            if state.get("v") != _CURSOR_VERSION or "since" not in state:
                raise SyncCursorError("Unsupported sync cursor")
            datetime.fromisoformat(state["since"])
            if state.get("cutoff"):
                datetime.fromisoformat(state["cutoff"])
            position = state.get("position")
            if position is not None:
                datetime.fromisoformat(position["updated_at"])
                if position["resource"] not in {"flashcard", "quiz_attempt"}:
                    raise SyncCursorError("Invalid sync cursor position")
                int(position["id"])
            return state
        except SyncCursorError:
            raise
        except (
            binascii.Error,
            UnicodeDecodeError,
            TypeError,
            ValueError,
            KeyError,
            json.JSONDecodeError,
        ) as exc:
            raise SyncCursorError("Invalid sync cursor") from exc

    @staticmethod
    def _to_sync_error(exc: Exception) -> SyncError:
        if isinstance(exc, SyncItemError):
            return SyncError(code=exc.code, message=exc.message)
        if isinstance(exc, ValidationError):
            return SyncError(code="invalid_payload", message=str(exc))
        if isinstance(exc, ValueError):
            message = str(exc)
            if ":" in message:
                code, detail = message.split(":", maxsplit=1)
                if code in {"bad_request", "not_found"}:
                    return SyncError(code=code, message=detail.strip())
            return SyncError(code="invalid_payload", message=message)
        return SyncError(code="internal_error", message="Item could not be synchronized")
