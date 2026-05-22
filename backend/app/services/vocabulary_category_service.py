import time
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.translation import VocabularyCategory, Vocabulary
from app.schemas.vocabulary_category import VocabularyCategoryCreate, VocabularyCategoryUpdate

def generate_id() -> int:
    # Snowflake ID generation logic (mocked to time based)
    return int(time.time() * 1000)

class VocabularyCategoryService:
    @staticmethod
    async def create_category(db: AsyncSession, user_id: int, req: VocabularyCategoryCreate):
        category = VocabularyCategory(
            id=generate_id(),
            user_id=user_id,
            name=req.name
        )
        db.add(category)
        await db.commit()
        await db.refresh(category)
        return category

    @staticmethod
    async def get_categories(db: AsyncSession, user_id: int):
        stmt = select(VocabularyCategory).where(VocabularyCategory.user_id == user_id).order_by(VocabularyCategory.name)
        result = await db.execute(stmt)
        return result.scalars().all()

    @staticmethod
    async def update_category(db: AsyncSession, category_id: int, user_id: int, req: VocabularyCategoryUpdate):
        stmt = select(VocabularyCategory).where(
            VocabularyCategory.id == category_id,
            VocabularyCategory.user_id == user_id
        )
        result = await db.execute(stmt)
        category = result.scalar_one_or_none()
        if not category:
            raise ValueError("Category not found")
        
        category.name = req.name
        await db.commit()
        await db.refresh(category)
        return category

    @staticmethod
    async def delete_category(db: AsyncSession, category_id: int, user_id: int):
        # 1. Check if category exists
        stmt = select(VocabularyCategory).where(
            VocabularyCategory.id == category_id,
            VocabularyCategory.user_id == user_id
        )
        result = await db.execute(stmt)
        category = result.scalar_one_or_none()
        if not category:
            raise ValueError("Category not found")
            
        # 2. Check if there are any vocabularies using this category
        vocab_stmt = select(Vocabulary.id).where(Vocabulary.category_id == category_id).limit(1)
        vocab_result = await db.execute(vocab_stmt)
        if vocab_result.scalar_one_or_none():
            raise PermissionError("Không thể xóa danh mục đang có từ vựng.")

        await db.delete(category)
        await db.commit()
        return {"message": "Đã xóa danh mục thành công"}
