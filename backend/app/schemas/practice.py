from typing import List
from pydantic import BaseModel, Field


class CheckQuestionRequest(BaseModel):
    MaCauHoi: int = Field(..., gt=0)
    DanhSachMaDapAn: List[int] = Field(..., min_length=1, description="Danh sách ID đáp án người dùng chọn")