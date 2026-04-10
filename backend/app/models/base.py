"""
Base class cho tất cả SQLAlchemy models.
Cấu hình chung: id, created_at, updated_at
"""
from datetime import datetime

from sqlalchemy import DateTime, Integer
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base class cho tất cả ORM models"""
    pass


class TimestampMixin:
    """Mixin thêm timestamp fields vào model"""
    
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )


class IdMixin:
    """Mixin thêm primary key"""
    
    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
