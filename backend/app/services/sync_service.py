"""
Sync Service — Business logic for offline-first vocabulary synchronisation.

Strategy: Last-Write-Wins based on updated_at (§5.2).
  1. For each record in batch:
     a. Find matching server record by (user_id, word, source_language, target_language).
     b. If NOT found → INSERT new Translation + Vocabulary.
     c. If found AND client.updated_at > server.updated_at → UPDATE.
     d. If found AND client.updated_at <= server.updated_at → UNCHANGED,
        return server data so client can reconcile.
  2. Return list of results with server_id for each client_id.
"""
import logging
import random
import time
from datetime import datetime, timezone

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.translation import Translation, Vocabulary
from app.schemas.sync import (
    SyncVocabularyItem,
    SyncVocabularyResultItem,
    SyncVocabularyResponse,
)


def _generate_snowflake_id() -> int:
    """Generate a Snowflake-like 64-bit integer ID.

    Matches the pattern used in VocabularyRepository.
    """
    return (int(time.time() * 1000) << 22) | random.randint(0, 4194303)

logger = logging.getLogger(__name__)


class SyncService:
    """Handles batch vocabulary synchronisation."""

    @staticmethod
    async def sync_vocabulary(
        db: AsyncSession,
        user_id: int,
        items: list[SyncVocabularyItem],
    ) -> SyncVocabularyResponse:
        """
        Synchronise a batch of vocabulary records for a user.

        Implements Last-Write-Wins (§5.2).
        """
        results: list[SyncVocabularyResultItem] = []

        for item in items:
            try:
                result = await SyncService._sync_single_item(
                    db, user_id, item,
                )
                results.append(result)
            except Exception as exc:
                logger.error(
                    "Sync failed for client_id=%s: %s",
                    item.client_id, exc,
                )
                # Skip failed items — the client will retry them next cycle.
                continue

        await db.commit()

        synced_count = sum(
            1 for r in results if r.status in ("created", "updated")
        )
        return SyncVocabularyResponse(
            synced_count=synced_count,
            results=results,
        )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    async def _sync_single_item(
        db: AsyncSession,
        user_id: int,
        item: SyncVocabularyItem,
    ) -> SyncVocabularyResultItem:
        """Process a single vocabulary item using Last-Write-Wins."""

        # 1. Try to find an existing Translation owned by this user
        #    that matches the word + language pair.
        stmt = select(Translation).where(
            and_(
                Translation.user_id == user_id,
                Translation.source_text == item.word,
                Translation.translated_text == item.translation,
                Translation.source_language == item.source_language,
                Translation.target_language == item.target_language,
            ),
        )
        result = await db.execute(stmt)
        existing: Translation | None = result.scalars().first()

        if existing is None:
            # ------ Case (b): INSERT new record ------
            return await SyncService._insert_new(db, user_id, item)

        # Ensure both datetimes are comparable (timezone-aware)
        server_updated = existing.updated_at
        client_updated = item.updated_at

        # Normalise to UTC-aware if naive
        if server_updated and server_updated.tzinfo is None:
            server_updated = server_updated.replace(tzinfo=timezone.utc)
        if client_updated.tzinfo is None:
            client_updated = client_updated.replace(tzinfo=timezone.utc)

        if client_updated > server_updated:
            # ------ Case (c): UPDATE ------
            existing.is_deleted = item.is_deleted
            existing.updated_at = datetime.now(timezone.utc)
            await db.flush()
            await db.refresh(existing)

            return SyncVocabularyResultItem(
                client_id=item.client_id,
                server_id=existing.id,
                status="updated",
            )
        else:
            # ------ Case (d): UNCHANGED ------
            return SyncVocabularyResultItem(
                client_id=item.client_id,
                server_id=existing.id,
                status="unchanged",
                server_updated_at=existing.updated_at,
            )

    @staticmethod
    async def _insert_new(
        db: AsyncSession,
        user_id: int,
        item: SyncVocabularyItem,
    ) -> SyncVocabularyResultItem:
        """Insert a brand-new Translation + Vocabulary record."""

        now = datetime.now(timezone.utc)
        translation_id = _generate_snowflake_id()

        translation = Translation(
            id=translation_id,
            user_id=user_id,
            source_language=item.source_language,
            target_language=item.target_language,
            source_text=item.word,
            translated_text=item.translation,
            translation_type="text",
            is_deleted=item.is_deleted,
            created_at=item.created_at or now,
            updated_at=now,
        )
        db.add(translation)
        await db.flush()

        # Also create a Vocabulary record linked to this translation.
        vocab_id = _generate_snowflake_id()
        vocabulary = Vocabulary(
            id=vocab_id,
            user_id=user_id,
            translation_id=translation_id,
            is_deleted=item.is_deleted,
            created_at=item.created_at or now,
            updated_at=now,
        )
        db.add(vocabulary)
        await db.flush()

        return SyncVocabularyResultItem(
            client_id=item.client_id,
            server_id=translation_id,
            status="created",
        )
