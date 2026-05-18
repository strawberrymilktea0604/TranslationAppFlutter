"""
Vocabulary Repository - Data access layer for vocabulary operations
"""
import logging
import time
import random
from typing import Optional, List, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import desc, and_, func, or_
from sqlalchemy.orm import joinedload

from app.models.translation import Vocabulary, Translation

logger = logging.getLogger(__name__)


class VocabularyRepository:
    """Repository for Vocabulary database operations"""
    
    @staticmethod
    async def create_vocabulary(
        db: AsyncSession,
        user_id: int,
        translation_id: int,
        category_id: Optional[int] = None
    ) -> Vocabulary:
        """
        Create a new vocabulary entry (bookmark a translation for learning).
        
        Args:
            db: Database session
            user_id: User ID who is bookmarking
            translation_id: Translation ID to bookmark
        
        Returns:
            Created Vocabulary model instance
        
        Raises:
            Exception: If translation doesn't exist or user doesn't have access
        """
        # Verify translation exists and belongs to user
        translation_result = await db.execute(
            select(Translation).filter(
                and_(
                    Translation.id == translation_id,
                    Translation.user_id == user_id,
                    Translation.is_deleted.is_(False)
                )
            )
        )
        translation = translation_result.scalars().first()
        
        if not translation:
            raise ValueError(f"Translation {translation_id} not found or doesn't belong to user")
        
        # Check if already in vocabulary
        existing = await db.execute(
            select(Vocabulary).filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.translation_id == translation_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        
        if existing.scalars().first():
            raise ValueError(f"Translation {translation_id} is already in vocabulary")
        
        # Create Snowflake-like ID
        unique_id = (int(time.time() * 1000) << 22) | random.randint(0, 4194303)
        
        new_vocabulary = Vocabulary(
            id=unique_id,
            user_id=user_id,
            translation_id=translation_id,
            category_id=category_id,
        )
        
        db.add(new_vocabulary)
        await db.commit()
        await db.refresh(new_vocabulary)
        
        logger.info(f"✅ Vocabulary entry created (ID: {new_vocabulary.id}, User: {user_id}, Translation: {translation_id})")
        return new_vocabulary
    
    @staticmethod
    async def create_multiple_vocabularies(
        db: AsyncSession,
        user_id: int,
        translation_ids: List[int]
    ) -> List[Vocabulary]:
        """
        Create multiple vocabulary entries at once.
        
        Args:
            db: Database session
            user_id: User ID who is bookmarking
            translation_ids: List of translation IDs to bookmark
        
        Returns:
            List of created Vocabulary entries
        """
        created_entries = []
        
        for translation_id in translation_ids:
            try:
                entry = await VocabularyRepository.create_vocabulary(db, user_id, translation_id)
                created_entries.append(entry)
            except ValueError as e:
                logger.warning(f"⚠️  Skipped vocabulary creation: {e}")
                continue
        
        return created_entries
    
    @staticmethod
    async def get_vocabulary_by_id(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: Optional[int] = None
    ) -> Optional[Vocabulary]:
        """
        Get a vocabulary entry by ID.
        
        Args:
            db: Database session
            vocabulary_id: Vocabulary ID
            user_id: Optional user ID for authorization check
        
        Returns:
            Vocabulary model or None if not found
        """
        filters = [
            Vocabulary.id == vocabulary_id,
            Vocabulary.is_deleted.is_(False)
        ]
        
        if user_id:
            filters.append(Vocabulary.user_id == user_id)
        
        result = await db.execute(
            select(Vocabulary)
            .options(joinedload(Vocabulary.translation), joinedload(Vocabulary.category_rel))
            .filter(and_(*filters))
        )
        return result.scalars().first()
    
    @staticmethod
    async def get_user_vocabularies(
        db: AsyncSession,
        user_id: int,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[Vocabulary], int]:
        """
        Get all vocabulary entries for a user with pagination.
        
        Args:
            db: Database session
            user_id: User ID
            skip: Number of records to skip (for pagination)
            limit: Number of records to return (max 100)
        
        Returns:
            Tuple of (list of Vocabulary entries, total count)
        """
        # Ensure limit is reasonable
        limit = min(limit, 100)
        
        # Get total count
        count_result = await db.execute(
            select(func.count(Vocabulary.id)).filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        total = count_result.scalar() or 0
        
        # Get paginated results
        result = await db.execute(
            select(Vocabulary)
            .filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
            .order_by(desc(Vocabulary.created_at))
            .offset(skip)
            .limit(limit)
        )
        
        vocabularies = result.scalars().all()
        return vocabularies, total
    
    @staticmethod
    async def get_user_vocabularies_with_translations(
        db: AsyncSession,
        user_id: int,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[Vocabulary], int]:
        """
        Get vocabulary entries with translation details (eager loaded).
        
        Args:
            db: Database session
            user_id: User ID
            skip: Number of records to skip
            limit: Number of records to return
        
        Returns:
            Tuple of (list of Vocabulary entries with translations, total count)
        """
        limit = min(limit, 100)
        
        # Get total count
        count_result = await db.execute(
            select(func.count(Vocabulary.id)).filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        total = count_result.scalar() or 0
        
        # Get paginated results with joined translation data
        result = await db.execute(
            select(Vocabulary)
            .options(joinedload(Vocabulary.translation), joinedload(Vocabulary.category_rel))
            .filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
            .order_by(desc(Vocabulary.created_at))
            .offset(skip)
            .limit(limit)
        )
        
        vocabularies = result.unique().scalars().all()
        return vocabularies, total
    
    @staticmethod
    async def delete_vocabulary(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int
    ) -> bool:
        """
        Soft delete a vocabulary entry (mark as deleted).
        
        Args:
            db: Database session
            vocabulary_id: Vocabulary ID
            user_id: User ID for authorization
        
        Returns:
            True if deleted, False if not found
        """
        result = await db.execute(
            select(Vocabulary).filter(
                and_(
                    Vocabulary.id == vocabulary_id,
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        vocabulary = result.scalars().first()
        
        if not vocabulary:
            return False
        
        vocabulary.is_deleted = True
        await db.commit()
        
        logger.info(f"✅ Vocabulary entry deleted (ID: {vocabulary_id}, User: {user_id})")
        return True
    
    @staticmethod
    async def delete_multiple_vocabularies(
        db: AsyncSession,
        vocabulary_ids: List[int],
        user_id: int
    ) -> int:
        """
        Soft delete multiple vocabulary entries.
        
        Args:
            db: Database session
            vocabulary_ids: List of vocabulary IDs to delete
            user_id: User ID for authorization
        
        Returns:
            Number of successfully deleted entries
        """
        result = await db.execute(
            select(Vocabulary).filter(
                and_(
                    Vocabulary.id.in_(vocabulary_ids),
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        vocabularies = result.scalars().all()
        
        for vocab in vocabularies:
            vocab.is_deleted = True
        
        await db.commit()
        
        logger.info(f"✅ Deleted {len(vocabularies)} vocabulary entries for user {user_id}")
        return len(vocabularies)
    
    @staticmethod
    async def restore_vocabulary(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int
    ) -> bool:
        """
        Restore a soft-deleted vocabulary entry.
        
        Args:
            db: Database session
            vocabulary_id: Vocabulary ID
            user_id: User ID for authorization
        
        Returns:
            True if restored, False if not found
        """
        result = await db.execute(
            select(Vocabulary).filter(
                and_(
                    Vocabulary.id == vocabulary_id,
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(True)
                )
            )
        )
        vocabulary = result.scalars().first()
        
        if not vocabulary:
            return False
        
        vocabulary.is_deleted = False
        await db.commit()
        
        logger.info(f"✅ Vocabulary entry restored (ID: {vocabulary_id}, User: {user_id})")
        return True
    
    @staticmethod
    async def search_vocabularies(
        db: AsyncSession,
        user_id: int,
        query: str,
        skip: int = 0,
        limit: int = 20
    ) -> Tuple[List[Vocabulary], int]:
        """
        Search vocabulary entries by source or translated text.
        
        Args:
            db: Database session
            user_id: User ID
            query: Search query
            skip: Number of records to skip
            limit: Number of records to return
        
        Returns:
            Tuple of (list of matching Vocabulary entries, total count)
        """
        
        limit = min(limit, 100)
        search_pattern = f"%{query}%"
        
        # Get total count
        count_result = await db.execute(
            select(func.count(Vocabulary.id)).distinct().filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False),
                    or_(
                        Translation.source_text.ilike(search_pattern),
                        Translation.translated_text.ilike(search_pattern)
                    )
                )
            ).select_from(Vocabulary).join(Translation)
        )
        total = count_result.scalar() or 0
        
        # Get paginated results
        result = await db.execute(
            select(Vocabulary)
            .options(joinedload(Vocabulary.translation), joinedload(Vocabulary.category_rel))
            .join(Translation)
            .filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False),
                    or_(
                        Translation.source_text.ilike(search_pattern),
                        Translation.translated_text.ilike(search_pattern)
                    )
                )
            )
            .order_by(desc(Vocabulary.created_at))
            .offset(skip)
            .limit(limit)
            .distinct()
        )
        
        vocabularies = result.unique().scalars().all()
        return vocabularies, total

    @staticmethod
    async def exists_for_any_user(
        db: AsyncSession,
        vocabulary_id: int,
    ) -> bool:
        """
        Check whether a vocabulary entry exists (regardless of owner).
        Used to distinguish 403 Forbidden from 404 Not Found.

        Args:
            db: Database session
            vocabulary_id: Vocabulary ID to check

        Returns:
            True if the entry exists and is not soft-deleted.
        """
        result = await db.execute(
            select(Vocabulary.id).filter(
                Vocabulary.id == vocabulary_id,
                Vocabulary.is_deleted.is_(False)
            )
        )
        return result.scalar() is not None

    @staticmethod
    async def update_vocabulary_progress(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int,
        mastery_level: Optional[int] = None,
        last_tested_at: Optional[object] = None,
    ) -> Optional["Vocabulary"]:
        """
        Update learning-progress fields on a vocabulary entry.

        Args:
            db: Database session
            vocabulary_id: Vocabulary ID
            user_id: Owner user ID for authorization
            mastery_level: New mastery level (0-5), or None to leave unchanged.
            last_tested_at: New last-tested timestamp, or None to leave unchanged.

        Returns:
            Updated Vocabulary instance, or None if not found / wrong owner.
        """
        result = await db.execute(
            select(Vocabulary)
            .options(joinedload(Vocabulary.translation), joinedload(Vocabulary.category_rel))
            .filter(
                and_(
                    Vocabulary.id == vocabulary_id,
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        vocabulary = result.scalars().first()

        if not vocabulary:
            return None

        if mastery_level is not None:
            vocabulary.mastery_level = mastery_level
        if last_tested_at is not None:
            vocabulary.last_tested_at = last_tested_at

        await db.commit()
        refreshed = await db.execute(
            select(Vocabulary)
            .options(joinedload(Vocabulary.translation), joinedload(Vocabulary.category_rel))
            .filter(
                and_(
                    Vocabulary.id == vocabulary_id,
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        vocabulary = refreshed.scalars().first()

        logger.info(
            "✅ Vocabulary progress updated (ID: %s, User: %s)",
            vocabulary_id,
            user_id,
        )
        return vocabulary
