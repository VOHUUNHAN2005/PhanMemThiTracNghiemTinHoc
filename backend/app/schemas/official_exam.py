from typing import List
from pydantic import BaseModel, Field


class SaveExamAnswerRequest(BaseModel):
    MaCauHoi: int = Field(..., gt=0)
    DanhSachMaDapAn: List[int] = Field(default_factory=list, description="Danh sách ID đáp án chọn (rỗng nếu bỏ chọn)")
