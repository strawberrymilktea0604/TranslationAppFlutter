"""
Translation Repository - Data access layer for translation operations
"""
import logging
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import desc

from app.models.translation import Translation
from app.schemas.translation import TranslationCreateDB, TranslationResponse

logger = logging.getLogger(__name__)


class TranslationRepository:
    """Repository for Translation database operations"""
    
    @staticmethod
    async def create_translation(
        db: AsyncSession,
        translation_data: TranslationCreateDB
    ) -> Translation:
        """
        Create and save a new translation record to database.
        
        Args:
            db: Database session
            translation_data: Translation data to save
        
        Returns:
            Created Translation model instance
        """
        new_translation = Translation(
            user_id=translation_data.user_id,
            source_text=translation_data.source_text,
            translated_text=translation_data.translated_text,
            source_language=translation_data.source_language,
            target_language=translation_data.target_language,
            translation_type=translation_data.translation_type,
        )
        
        db.add(new_translation)
        await db.commit()
        await db.refresh(new_translation)
        
        logger.info(f"✅ Translation saved (ID: {new_translation.id}, User: {translation_data.user_id})")
        return new_translation
    
    @staticmethod
    async def get_translation_by_id(
        db: AsyncSession,
        translation_id: int
    ) -> Optional[Translation]:
        """
        Get a translation by ID.
        
        Args:
            db: Database session
            translation_id: Translation ID
        
        Returns:
            Translation model or None if not found
        """
        result = await db.execute(
            select(Translation).filter(Translation.id == translation_id)
        )
        return result.scalars().first()
    
    @staticmethod
    async def get_user_translations(
        db: AsyncSession,
        user_id: int,
        skip: int = 0,
        limit: int = 50
    ) -> tuple[List[Translation], int]:
        """
        Get all translations for a specific user (paginated).
        
        Args:
            db: Database session
            user_id: User ID
            skip: Number of records to skip (pagination)
            limit: Maximum records to return
        
        Returns:
            Tuple of (translations list, total count)
        """
        # Get total count
        count_result = await db.execute(
            select(Translation).filter(
                Translation.user_id == user_id,
                Translation.is_deleted == False
            )
        )
        total = len(count_result.scalars().all())
        
        # Get paginated results
        result = await db.execute(
            select(Translation)
            .filter(
                Translation.user_id == user_id,
                Translation.is_deleted == False
            )
            .order_by(desc(Translation.created_at))
            .offset(skip)
            .limit(limit)
        )
        translations = result.scalars().all()
        
        return translations, total
    
    @staticmethod
    async def check_existing_translation(
        db: AsyncSession,
        user_id: int,
        source_text: str,
        source_language: str,
        target_language: str
    ) -> Optional[Translation]:
        """
        Check if a translation already exists in database.
        Used to populate local cache if not in Redis.
        
        Args:
            db: Database session
            user_id: User ID
            source_text: Source text (will be normalized for comparison)
            source_language: Source language
            target_language: Target language
        
        Returns:
            Translation if found, None otherwise
        """
        result = await db.execute(
            select(Translation).filter(
                Translation.user_id == user_id,
                Translation.source_text == source_text,
                Translation.source_language == source_language,
                Translation.target_language == target_language,
                Translation.is_deleted == False
            )
        )
        return result.scalars().first()
    
    @staticmethod
    async def delete_translation(
        db: AsyncSession,
        translation_id: int,
        user_id: int
    ) -> bool:
        """
        Soft delete a translation (mark as deleted).
        
        Args:
            db: Database session
            translation_id: Translation ID
            user_id: User ID (for authorization check)
        
        Returns:
            True if deleted successfully, False if not found or unauthorized
        """
        result = await db.execute(
            select(Translation).filter(
                Translation.id == translation_id,
                Translation.user_id == user_id
            )
        )
        translation = result.scalars().first()
        
        if not translation:
            logger.warning(f"Translation not found (ID: {translation_id})")
            return False
        
        translation.is_deleted = True
        await db.commit()
        logger.info(f"✅ Translation soft-deleted (ID: {translation_id})")
        return True
    
    @staticmethod
    async def get_translation_history(
        db: AsyncSession,
        user_id: int,
        source_language: str,
        target_language: str,
        limit: int = 10
    ) -> List[Translation]:
        """
        Get recent translations for a language pair (useful for suggestions).
        
        Args:
            db: Database session
            user_id: User ID
            source_language: Source language
            target_language: Target language
            limit: Maximum records
        
        Returns:
            List of translations
        """
        result = await db.execute(
            select(Translation)
            .filter(
                Translation.user_id == user_id,
                Translation.source_language == source_language,
                Translation.target_language == target_language,
                Translation.is_deleted == False
            )
            .order_by(desc(Translation.created_at))
            .limit(limit)
        )
        return result.scalars().all()
