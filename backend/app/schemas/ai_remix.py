from pydantic import BaseModel, Field
from typing import List

class RemixedQuestionModel(BaseModel):
    """
    Schema khắt khe cho một câu hỏi được AI tạo ra hoặc remix.
    Sử dụng để ép định dạng dữ liệu đầu ra (Structured Output) từ Google Gemini API.
    """
    content: str = Field(
        ..., 
        description="Nội dung câu hỏi (ví dụ: câu hỏi trắc nghiệm từ vựng, ngữ pháp)"
    )
    choices: List[str] = Field(
        ..., 
        min_length=2, 
        max_length=4,
        description="Danh sách các đáp án lựa chọn (thường là 4 đáp án A, B, C, D)"
    )
    correct_answer: str = Field(
        ..., 
        description="Đáp án đúng (LƯU Ý: Phải trùng khớp chính xác 100% với một trong các giá trị nằm trong mảng choices)"
    )
    explanation: str = Field(
        default="", 
        description="Giải thích chi tiết lý do tại sao đáp án đó lại đúng"
    )


class AIRemixResponseModel(BaseModel):
    """
    Schema tổng chứa danh sách các câu hỏi đã được AI remix.
    Đảm bảo Gemini trả về đúng một JSON Object chứa mảng questions.
    """
    questions: List[RemixedQuestionModel] = Field(
        ..., 
        description="Danh sách các câu hỏi đã được AI tạo ra hoặc remix"
    )
