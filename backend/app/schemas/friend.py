from pydantic import BaseModel, Field


class SendFriendRequest(BaseModel):
    MaNguoiNhan: int = Field(..., gt=0, description="ID của người dùng muốn kết bạn")


class RespondFriendRequest(BaseModel):
    MaKetBan: int = Field(..., gt=0, description="ID bản ghi trong bảng KetBan")
    ChapNhan: bool = Field(..., description="True = Đồng ý, False = Từ chối")