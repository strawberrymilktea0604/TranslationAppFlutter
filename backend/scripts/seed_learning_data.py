"""
Seed script — insert sample question banks and questions.

Usage (from backend/ with .venv active):
    python scripts/seed_learning_data.py

Idempotent: skips any bank whose title already exists, so it is safe to re-run.
"""
import asyncio
import os
import sys
from pathlib import Path

# Make sure app imports work when running from the backend/ directory
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("SECRET_KEY", "seed-script-placeholder-at-least-32-chars")

from sqlalchemy import select  # noqa: E402
from sqlalchemy.ext.asyncio import AsyncSession  # noqa: E402
from app.core.database import engine  # noqa: E402
from app.models.learning import Question, QuestionBank  # noqa: E402

engine.echo = False
engine.sync_engine.echo = False

# ─────────────────────────────────────────────
# Seed data
# ─────────────────────────────────────────────

BANKS = [
    {
        "title": "English Grammar Basics",
        "description": "Test your knowledge of fundamental English grammar rules.",
        "duration_minutes": 10,
        "questions": [
            {
                "content": "Which sentence is grammatically correct?",
                "choices": [
                    "A. She don't know the answer.",
                    "B. She doesn't know the answer.",
                    "C. She not know the answer.",
                    "D. She no know the answer.",
                ],
                "correct_answer": "B",
            },
            {
                "content": "Choose the correct form of the verb: 'He ___ to school every day.'",
                "choices": ["A. go", "B. goes", "C. going", "D. gone"],
                "correct_answer": "B",
            },
            {
                "content": "Which word is a preposition?",
                "choices": ["A. quickly", "B. beautiful", "C. under", "D. run"],
                "correct_answer": "C",
            },
            {
                "content": "Select the correct past tense of 'write'.",
                "choices": ["A. writed", "B. written", "C. wrote", "D. writ"],
                "correct_answer": "C",
            },
            {
                "content": "Which sentence uses the present perfect correctly?",
                "choices": [
                    "A. I have ate lunch already.",
                    "B. I have eaten lunch already.",
                    "C. I has eaten lunch already.",
                    "D. I eating lunch already.",
                ],
                "correct_answer": "B",
            },
            {
                "content": "What is the plural of 'child'?",
                "choices": ["A. childs", "B. childes", "C. children", "D. childrens"],
                "correct_answer": "C",
            },
        ],
    },
    {
        "title": "Vietnamese Vocabulary — Travel",
        "description": "Common Vietnamese words and phrases for travellers.",
        "duration_minutes": 8,
        "questions": [
            {
                "content": "What does 'xin chào' mean?",
                "choices": ["A. Goodbye", "B. Thank you", "C. Hello", "D. Sorry"],
                "correct_answer": "C",
            },
            {
                "content": "Which word means 'airport' in Vietnamese?",
                "choices": ["A. bệnh viện", "B. sân bay", "C. nhà ga", "D. khách sạn"],
                "correct_answer": "B",
            },
            {
                "content": "How do you say 'How much does this cost?' in Vietnamese?",
                "choices": [
                    "A. Cái này ở đâu?",
                    "B. Tôi muốn cái này.",
                    "C. Cái này giá bao nhiêu?",
                    "D. Cái này tên gì?",
                ],
                "correct_answer": "C",
            },
            {
                "content": "What is 'cảm ơn'?",
                "choices": ["A. You're welcome", "B. Please", "C. Excuse me", "D. Thank you"],
                "correct_answer": "D",
            },
            {
                "content": "Which phrase means 'I don't understand'?",
                "choices": [
                    "A. Tôi không biết tiếng Việt.",
                    "B. Tôi không hiểu.",
                    "C. Tôi không thích.",
                    "D. Tôi không có.",
                ],
                "correct_answer": "B",
            },
            {
                "content": "What does 'nhà hàng' mean?",
                "choices": ["A. Hotel", "B. Market", "C. Hospital", "D. Restaurant"],
                "correct_answer": "D",
            },
        ],
    },
]


# ─────────────────────────────────────────────
# Main seeder
# ─────────────────────────────────────────────

async def seed() -> None:
    async with AsyncSession(engine) as session:
        for bank_data in BANKS:
            # Check if this bank already exists (idempotent)
            existing = await session.execute(
                select(QuestionBank).where(QuestionBank.title == bank_data["title"])
            )
            if existing.scalar_one_or_none():
                print(f"  - Skipping '{bank_data['title']}' - already exists.")
                continue

            bank = QuestionBank(
                title=bank_data["title"],
                description=bank_data["description"],
                duration_minutes=bank_data["duration_minutes"],
                is_deleted=False,
            )
            session.add(bank)
            await session.flush()  # populate bank.id before adding questions

            for q_data in bank_data["questions"]:
                question = Question(
                    bank_id=bank.id,
                    content=q_data["content"],
                    choices=q_data["choices"],
                    correct_answer=q_data["correct_answer"],
                    is_deleted=False,
                )
                session.add(question)

            await session.commit()
            print(
                f"  + Inserted '{bank_data['title']}' "
                f"with {len(bank_data['questions'])} questions."
            )

    print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
