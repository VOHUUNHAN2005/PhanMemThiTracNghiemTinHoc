import os
import shutil
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user
from app.schemas.user import DeviceSyncRequest, UserUpdateProfile

router = APIRouter(prefix="/api/users", tags=["Auth & Users"])

from security import get_current_user, verify_firebase_token
from app.schemas.user import DeviceSyncRequest, UserUpdateProfile, UserRegisterRequest


ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


@router.post("/upload_avatar")
def upload_avatar(
    request: Request,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    original_filename = file.filename or "avatar.jpg"
    ext = os.path.splitext(original_filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Chỉ chấp nhận tệp ảnh định dạng JPG, JPEG, PNG hoặc WEBP.",
        )

    os.makedirs("static/avatars", exist_ok=True)
    filename = f"user_{current_user['MaNguoiDung']}_{uuid.uuid4().hex[:8]}{ext}"
    file_path = os.path.join("static", "avatars", filename)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    finally:
        file.file.close()

    old_avatar = current_user.get("AnhDaiDien")
    if old_avatar and "/static/avatars/" in old_avatar:
        old_filename = old_avatar.split("/static/avatars/")[-1]
        old_path = os.path.join("static", "avatars", old_filename)
        if os.path.exists(old_path):
            try:
                os.remove(old_path)
            except OSError:
                pass

    base_url = str(request.base_url).rstrip("/")
    avatar_url = f"{base_url}/static/avatars/{filename}"

    db.execute(
        text("UPDATE NguoiDung SET AnhDaiDien = :url WHERE MaNguoiDung = :id"),
        {"url": avatar_url, "id": current_user["MaNguoiDung"]},
    )
    db.commit()

    return {
        "message": "Cập nhật ảnh đại diện thành công!",
        "AnhDaiDien": avatar_url,
    }
@router.post("/register", status_code=status.HTTP_201_CREATED)
def register_user(
    payload: UserRegisterRequest,
    token_data: dict = Depends(verify_firebase_token),
    db: Session = Depends(get_db),
):
    firebase_uid = token_data.get("uid")
    email = token_data.get("email")

    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tài khoản Firebase thiếu thông tin Email.",
        )

    existing_user = db.execute(
        text("SELECT MaNguoiDung FROM NguoiDung WHERE FirebaseUid = :uid OR Email = :email"),
        {"uid": firebase_uid, "email": email},
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tài khoản hoặc Email này đã được đăng ký trước đó.",
        )

    ma_hang_mac_dinh = db.execute(
        text("SELECT TOP 1 MaHang FROM CapBacHang ORDER BY ThuTuHang ASC")
    ).scalar()

    if not ma_hang_mac_dinh:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Hệ thống chưa cấu hình danh mục bậc hạng (CapBacHang).",
        )

    try:
        db.execute(
            text("""
                INSERT INTO NguoiDung (
                    FirebaseUid, TenDangNhap, Email, MatKhauHash, HoTen, 
                    AnhDaiDien, VaiTro, SoCupHienTai, MaHangHienTai, 
                    TrangThaiOnline, HoatDongCuoi, TrangThaiTaiKhoan
                )
                VALUES (
                    :uid, :username, :email, 'FIREBASE_AUTH', :hoten, 
                    :avatar, 'THI_SINH', 0, :mahang, 
                    0, SYSUTCDATETIME(), 'HOAT_DONG'
                )
            """),
            {
                "uid": firebase_uid,
                "username": payload.TenDangNhap.strip(),
                "email": email,
                "hoten": payload.HoTen.strip(),
                "avatar": payload.AnhDaiDien,
                "mahang": ma_hang_mac_dinh,
            },
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tên đăng nhập này đã có người sử dụng, vui lòng chọn tên khác.",
        )

    return {"message": "Đăng ký tài khoản thành công!"}
@router.get("/get_me")
def get_my_profile(current_user: dict = Depends(get_current_user)):
    return {
        "MaNguoiDung": current_user["MaNguoiDung"],
        "FirebaseUid": current_user["FirebaseUid"],
        "TenDangNhap": current_user["TenDangNhap"],
        "Email": current_user["Email"],
        "HoTen": current_user["HoTen"],
        "AnhDaiDien": current_user["AnhDaiDien"],
        "VaiTro": current_user["VaiTro"],
        "SoCupHienTai": current_user["SoCupHienTai"],
        "MaHangHienTai": current_user["MaHangHienTai"],
        "TenHang": current_user["TenHang"],
        "TrangThaiOnline": current_user["TrangThaiOnline"],
        "TrangThaiTaiKhoan": current_user["TrangThaiTaiKhoan"],
    }

@router.put("/update_me")
def update_my_profile(
    payload: UserUpdateProfile,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    update_fields = payload.model_dump(exclude_unset=True)
    if not update_fields:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Không có dữ liệu nào để cập nhật.",
        )

    set_clause = ", ".join([f"{col} = :{col}" for col in update_fields.keys()])
    update_fields["MaNguoiDung"] = current_user["MaNguoiDung"]

    try:
        db.execute(
            text(f"UPDATE NguoiDung SET {set_clause} WHERE MaNguoiDung = :MaNguoiDung"),
            update_fields,
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tên đăng nhập này đã được sử dụng.",
        )

    return {"message": "Cập nhật hồ sơ thành công!"}


@router.post("/device")
def sync_device_and_push_token(
    payload: DeviceSyncRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.execute(
        text("""
            UPDATE NguoiDung
            SET MaThietBiHienTai = COALESCE(:device, MaThietBiHienTai),
                PushToken = COALESCE(:push_token, PushToken)
            WHERE MaNguoiDung = :id
        """),
        {
            "device": payload.MaThietBiHienTai,
            "push_token": payload.PushToken,
            "id": current_user["MaNguoiDung"],
        },
    )
    db.commit()
    return {"message": "Đã cập nhật thông tin thiết bị."}


@router.post("/logout")
def logout_user(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.execute(
        text("""
            UPDATE NguoiDung
            SET TrangThaiOnline = 0, HoatDongCuoi = SYSUTCDATETIME()
            WHERE MaNguoiDung = :id
        """),
        {"id": current_user["MaNguoiDung"]},
    )
    db.commit()
    return {"message": "Đã đăng xuất."}