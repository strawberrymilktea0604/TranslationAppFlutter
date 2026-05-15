from typing import List, Annotated
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.dependencies import DBSession, get_current_user
from app.models.learning import QuestionBank
from app.models.user import User
from app.schemas.learning import QuestionBankBase, QuestionBankDetail

router = APIRouter(prefix="/learning", tags=["learning"])

@router.get("/banks", response_model=List[QuestionBankBase])
async def get_question_banks(
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)],
    skip: int = 0,
    limit: int = 100
):
    """
    Get a list of question banks.
    """
    stmt = select(QuestionBank).where(QuestionBank.is_deleted.is_(False)).offset(skip).limit(limit)
    result = await db.execute(stmt)
    banks = result.scalars().all()
    return banks

@router.get("/banks/{bank_id}", response_model=QuestionBankDetail)
async def get_question_bank_detail(
    bank_id: int,
    db: DBSession,
    current_user: Annotated[User, Depends(get_current_user)]
):
    """
    Get details of a specific question bank including its questions.
    """
    stmt = select(QuestionBank).where(
        QuestionBank.id == bank_id, 
        QuestionBank.is_deleted.is_(False)
    ).options(
        selectinload(QuestionBank.questions)
    )
    result = await db.execute(stmt)
    bank = result.scalar_one_or_none()
    
    if not bank:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Question bank not found"
        )
        
    
    # Construct Pydantic model to safely filter questions
    response_data = QuestionBankDetail.model_validate(bank)
    response_data.questions = [q for q in response_data.questions if not q.is_deleted]
        
    return response_data
