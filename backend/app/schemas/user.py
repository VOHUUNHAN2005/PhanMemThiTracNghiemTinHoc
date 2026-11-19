from typing import Optional
from pydantic import BaseModel, Field


class UserRegisterRequest(BaseModel):
    TenDangNhap: str = Field(..., min_length=3, max_length=50)
    HoTen: str = Field(..., min_length=1, max_length=100)
    AnhDaiDien: str | None = Field(default=None, max_length=500)

class UserUpdateProfile(BaseModel):
    HoTen: Optional[str] = Field(None, min_length=2, max_length=100)
    TenDangNhap: Optional[str] = Field(None, min_length=3, max_length=50)
    AnhDaiDien: Optional[str] = Field(None, max_length=500)


class DeviceSyncRequest(BaseModel):
    MaThietBiHienTai: Optional[str] = Field(None, max_length=255)
    PushToken: Optional[str] = Field(None, max_length=500)