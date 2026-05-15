from typing import Any, Dict, Optional, List, TypeVar, Generic

from pydantic import BaseModel, Field

T = TypeVar('T')

class SuccessResponse(BaseModel):
    status: str = "success"
    data: Any
    metadata: Optional[Dict[str, Any]] = None


class ErrorResponse(BaseModel):
    status: str = "error"
    code: str
    message: str


class PaginationMetadata(BaseModel):
    """Metadata for paginated responses"""
    total: int = Field(..., description="Total number of records")
    skip: int = Field(default=0, description="Number of records skipped")
    limit: int = Field(default=50, description="Records per page")
    has_more: bool = Field(..., description="Whether there are more records")
    
    @classmethod
    def create(cls, total: int, skip: int, limit: int) -> "PaginationMetadata":
        """Factory method to create pagination metadata"""
        return cls(
            total=total,
            skip=skip,
            limit=limit,
            has_more=(skip + limit) < total
        )


class PaginatedResponse(BaseModel, Generic[T]):
    """Generic paginated response wrapper"""
    status: str = "success"
    data: List[T]
    pagination: PaginationMetadata
