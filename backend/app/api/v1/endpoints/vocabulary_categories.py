import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.common import SuccessResponse
from app.schemas.vocabulary_category import (
    VocabularyCategoryCreate,
    VocabularyCategoryUpdate,
    VocabularyCategoryResponse
)
from app.services.vocabulary_category_service import VocabularyCategoryService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vocabulary-categories", tags=["vocabulary_categories"])

@router.post("", response_model=VocabularyCategoryResponse, status_code=status.HTTP_201_CREATED)
async def create_category(req: VocabularyCategoryCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await VocabularyCategoryService.create_category(db, current_user.id, req)
    except Exception as e:
        logger.error(f"Error creating category: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.get("", response_model=List[VocabularyCategoryResponse])
async def list_categories(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await VocabularyCategoryService.get_categories(db, current_user.id)
    except Exception as e:
        logger.error(f"Error listing categories: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.put("/{category_id}", response_model=VocabularyCategoryResponse)
async def update_category(category_id: int, req: VocabularyCategoryUpdate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        return await VocabularyCategoryService.update_category(db, category_id, current_user.id, req)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error updating category: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

@router.delete("/{category_id}", response_model=SuccessResponse)
async def delete_category(category_id: int, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        result = await VocabularyCategoryService.delete_category(db, category_id, current_user.id)
        return SuccessResponse(success=True, message=result["message"])
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error deleting category: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")
