from typing import Any

from pydantic import BaseModel


class SuccessResponse(BaseModel):
    status: str = "success"
    data: Any


class ErrorResponse(BaseModel):
    status: str = "error"
    code: str
    message: str
