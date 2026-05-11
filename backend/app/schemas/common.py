from typing import Any, Dict, Optional

from pydantic import BaseModel


class SuccessResponse(BaseModel):
    status: str = "success"
    data: Any
    metadata: Optional[Dict[str, Any]] = None


class ErrorResponse(BaseModel):
    status: str = "error"
    code: str
    message: str
