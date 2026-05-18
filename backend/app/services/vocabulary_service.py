"""
Vocabulary Service - Business logic for vocabulary management
"""
import logging
from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.translation import Vocabulary, Translation
from app.repositories.vocabulary_repository import VocabularyRepository
from app.schemas.vocabulary import VocabularyDetailResponse, VocabularyListResponse, VocabularyProgressUpdate

logger = logging.getLogger(__name__)


class VocabularyService:
    """Service for vocabulary-related business logic"""
    
    @staticmethod
    async def add_to_vocabulary(
        db: AsyncSession,
        user_id: int,
        translation_id: int,
        category_id: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Add a translation to user's vocabulary for learning.
        
        Args:
            db: Database session
            user_id: User ID
            translation_id: Translation ID to bookmark
        
        Returns:
            Dictionary with success status and vocabulary ID
        
        Raises:
            ValueError: If translation doesn't exist or is already in vocabulary
        """
        try:
            vocabulary = await VocabularyRepository.create_vocabulary(
                db, user_id, translation_id, category_id
            )
            return {
                "success": True,
                "message": "Translation added to vocabulary successfully",
                "vocabulary_id": vocabulary.id,
                "created_at": vocabulary.created_at
            }
        except ValueError as e:
            logger.warning(f"⚠️  Failed to add to vocabulary: {e}")
            raise
    
    @staticmethod
    async def add_multiple_to_vocabulary(
        db: AsyncSession,
        user_id: int,
        translation_ids: List[int]
    ) -> Dict[str, Any]:
        """
        Add multiple translations to vocabulary at once.
        
        Args:
            db: Database session
            user_id: User ID
            translation_ids: List of translation IDs
        
        Returns:
            Dictionary with results
        """
        if not translation_ids:
            raise ValueError("translation_ids cannot be empty")
        
        if len(translation_ids) > 50:
            raise ValueError("Cannot add more than 50 translations at once")
        
        vocabularies = await VocabularyRepository.create_multiple_vocabularies(
            db, user_id, translation_ids
        )
        
        return {
            "success": True,
            "message": f"Added {len(vocabularies)} translations to vocabulary",
            "count": len(vocabularies),
            "vocabulary_ids": [v.id for v in vocabularies]
        }
    
    @staticmethod
    async def get_vocabulary_detail(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int
    ) -> VocabularyDetailResponse:
        """
        Get detailed vocabulary entry with translation information.

        Raises:
            PermissionError: If vocabulary exists but belongs to another user (→ 403).
            ValueError: If vocabulary does not exist (→ 404).
        """
        vocabulary = await VocabularyRepository.get_vocabulary_by_id(
            db, vocabulary_id, user_id
        )

        if not vocabulary:
            # Distinguish: does the record exist at all?
            exists = await VocabularyRepository.exists_for_any_user(db, vocabulary_id)
            if exists:
                raise PermissionError(
                    f"Vocabulary entry {vocabulary_id} belongs to another user"
                )
            raise ValueError(f"Vocabulary entry {vocabulary_id} not found")

        # Get translation details
        translation = vocabulary.translation
        if not translation:
            raise ValueError(
                f"Associated translation not found for vocabulary {vocabulary_id}"
            )

        return VocabularyDetailResponse(
            id=vocabulary.id,
            user_id=vocabulary.user_id,
            translation_id=vocabulary.translation_id,
            is_deleted=vocabulary.is_deleted,
            mastery_level=vocabulary.mastery_level or 0,
            last_tested_at=vocabulary.last_tested_at,
            created_at=vocabulary.created_at,
            updated_at=vocabulary.updated_at,
            source_language=translation.source_language,
            target_language=translation.target_language,
            source_text=translation.source_text,
            translated_text=translation.translated_text,
            translation_type=translation.translation_type,
            translation_created_at=translation.created_at,
            category_id=vocabulary.category_id,
            category=vocabulary.category_rel.name if vocabulary.category_rel else "Chưa phân loại"
        )
    
    @staticmethod
    async def list_vocabularies(
        db: AsyncSession,
        user_id: int,
        page: int = 1,
        page_size: int = 20,
        search_query: Optional[str] = None
    ) -> VocabularyListResponse:
        """
        Get paginated list of user's vocabulary with optional search.
        
        Args:
            db: Database session
            user_id: User ID
            page: Page number (1-indexed)
            page_size: Items per page (max 100)
            search_query: Optional search query
        
        Returns:
            VocabularyListResponse with paginated vocabulary entries
        """
        # Validate pagination
        page = max(page, 1)
        page_size = min(max(page_size, 1), 100)
        skip = (page - 1) * page_size
        
        # Get vocabularies
        if search_query and search_query.strip():
            vocabularies, total = await VocabularyRepository.search_vocabularies(
                db, user_id, search_query.strip(), skip, page_size
            )
        else:
            vocabularies, total = await VocabularyRepository.get_user_vocabularies_with_translations(
                db, user_id, skip, page_size
            )
        
        # Convert to detail responses
        items = []
        for vocab in vocabularies:
            try:
                translation = vocab.translation
                detail = VocabularyDetailResponse(
                    id=vocab.id,
                    user_id=vocab.user_id,
                    translation_id=vocab.translation_id,
                    is_deleted=vocab.is_deleted,
                    mastery_level=vocab.mastery_level or 0,
                    last_tested_at=vocab.last_tested_at,
                    created_at=vocab.created_at,
                    updated_at=vocab.updated_at,
                    source_language=translation.source_language,
                    target_language=translation.target_language,
                    source_text=translation.source_text,
                    translated_text=translation.translated_text,
                    translation_type=translation.translation_type,
                    translation_created_at=translation.created_at,
                    category_id=vocab.category_id,
                    category=vocab.category_rel.name if vocab.category_rel else "Chưa phân loại"
                )
                items.append(detail)
            except Exception as e:
                logger.error(f"❌ Error converting vocabulary {vocab.id}: {e}")
                continue
        
        # Calculate pagination info
        total_pages = (total + page_size - 1) // page_size
        has_next = page < total_pages
        has_prev = page > 1
        
        return VocabularyListResponse(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
            has_next=has_next,
            has_prev=has_prev
        )
    
    @staticmethod
    async def remove_from_vocabulary(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int
    ) -> Dict[str, Any]:
        """
        Remove a vocabulary entry (soft delete).
        
        Args:
            db: Database session
            vocabulary_id: Vocabulary ID
            user_id: User ID for authorization
        
        Returns:
            Dictionary with result
        
        Raises:
            ValueError: If vocabulary not found
        """
        success = await VocabularyRepository.delete_vocabulary(
            db, vocabulary_id, user_id
        )
        
        if not success:
            raise ValueError(f"Vocabulary entry {vocabulary_id} not found")
        
        return {
            "success": True,
            "message": "Vocabulary entry removed successfully",
            "vocabulary_id": vocabulary_id
        }
    
    @staticmethod
    async def remove_multiple_from_vocabulary(
        db: AsyncSession,
        vocabulary_ids: List[int],
        user_id: int
    ) -> Dict[str, Any]:
        """
        Remove multiple vocabulary entries.
        
        Args:
            db: Database session
            vocabulary_ids: List of vocabulary IDs
            user_id: User ID for authorization
        
        Returns:
            Dictionary with results
        """
        if not vocabulary_ids:
            raise ValueError("vocabulary_ids cannot be empty")
        
        if len(vocabulary_ids) > 50:
            raise ValueError("Cannot delete more than 50 entries at once")
        
        count = await VocabularyRepository.delete_multiple_vocabularies(
            db, vocabulary_ids, user_id
        )
        
        return {
            "success": True,
            "message": f"Removed {count} vocabulary entries",
            "count": count
        }
    
    @staticmethod
    async def restore_vocabulary_entry(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int
    ) -> dict:
        """
        Restore a previously deleted vocabulary entry.
        """
        success = await VocabularyRepository.restore_vocabulary(
            db, vocabulary_id, user_id
        )

        if not success:
            raise ValueError(f"Deleted vocabulary entry {vocabulary_id} not found")

        return {
            "success": True,
            "message": "Vocabulary entry restored successfully",
            "vocabulary_id": vocabulary_id
        }

    @staticmethod
    async def update_vocabulary_progress(
        db: AsyncSession,
        vocabulary_id: int,
        user_id: int,
        update: VocabularyProgressUpdate,
    ) -> VocabularyDetailResponse:
        """
        Apply progress-only updates (mastery_level, last_tested_at) to a vocabulary entry.

        Raises:
            PermissionError: If the entry exists but belongs to another user (→ 403).
            ValueError: If the entry does not exist (→ 404).
        """
        vocabulary = await VocabularyRepository.update_vocabulary_progress(
            db,
            vocabulary_id=vocabulary_id,
            user_id=user_id,
            mastery_level=update.mastery_level,
            last_tested_at=update.last_tested_at,
        )

        if vocabulary is None:
            exists = await VocabularyRepository.exists_for_any_user(db, vocabulary_id)
            if exists:
                raise PermissionError(
                    f"Vocabulary entry {vocabulary_id} belongs to another user"
                )
            raise ValueError(f"Vocabulary entry {vocabulary_id} not found")

        translation = vocabulary.translation
        if not translation:
            raise ValueError(
                f"Associated translation not found for vocabulary {vocabulary_id}"
            )

        return VocabularyDetailResponse(
            id=vocabulary.id,
            user_id=vocabulary.user_id,
            translation_id=vocabulary.translation_id,
            is_deleted=vocabulary.is_deleted,
            mastery_level=vocabulary.mastery_level or 0,
            last_tested_at=vocabulary.last_tested_at,
            created_at=vocabulary.created_at,
            updated_at=vocabulary.updated_at,
            source_language=translation.source_language,
            target_language=translation.target_language,
            source_text=translation.source_text,
            translated_text=translation.translated_text,
            translation_type=translation.translation_type,
            translation_created_at=translation.created_at,
            category_id=vocabulary.category_id,
            category=vocabulary.category_rel.name if vocabulary.category_rel else "Chưa phân loại"
        )
    
    @staticmethod
    async def get_user_vocabulary_count(
        db: AsyncSession,
        user_id: int
    ) -> Dict[str, Any]:
        """
        Get statistics about user's vocabulary.
        
        Args:
            db: Database session
            user_id: User ID
        
        Returns:
            Dictionary with vocabulary statistics
        """
        from sqlalchemy import func, and_
        from sqlalchemy.future import select
        
        # Total vocabulary entries
        total_result = await db.execute(
            select(func.count(Vocabulary.id)).filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            )
        )
        total = total_result.scalar() or 0
        
        # Vocabulary by translation type
        type_result = await db.execute(
            select(
                Translation.translation_type,
                func.count(Vocabulary.id)
            ).join(Vocabulary).filter(
                and_(
                    Vocabulary.user_id == user_id,
                    Vocabulary.is_deleted.is_(False)
                )
            ).group_by(Translation.translation_type)
        )
        
        type_stats = dict(type_result.all())
        
        return {
            "total_entries": total,
            "by_type": type_stats
        }
