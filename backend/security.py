import uuid
import firebase_admin
from firebase_admin import auth, credentials
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db

if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
security = HTTPBearer()


def verify_firebase_token(
    res: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    try:
        return auth.verify_id_token(res.credentials, clock_skew_seconds=10)
    except TypeError:
        try:
            return auth.verify_id_token(res.credentials)
        except Exception as e:
            print("Verify Firebase token error:", e)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token không hợp lệ hoặc đã hết hạn.",
            )
    except Exception as e:
        print("Verify Firebase token error:", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn.",
        )


def get_current_user(
    token_data: dict = Depends(verify_firebase_token),
    db: Session = Depends(get_db),
) -> dict:
    firebase_uid = token_data.get("uid")
    email = token_data.get("email")
    name = token_data.get("name") or (email.split("@")[0] if email else "ThiSinh")
    picture = token_data.get("picture")

    query_find = text("""
        SELECT nd.*, cb.TenHang
        FROM NguoiDung nd
        JOIN CapBacHang cb ON nd.MaHangHienTai = cb.MaHang
        WHERE nd.FirebaseUid = :uid
    """)
    user = db.execute(query_find, {"uid": firebase_uid}).mappings().first()

    if not user:
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tài khoản Firebase thiếu thông tin Email.",
            )

        ma_hang_mac_dinh = db.execute(
            text("SELECT TOP 1 MaHang FROM CapBacHang ORDER BY ThuTuHang ASC")
        ).scalar()

        if not ma_hang_mac_dinh:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Hệ thống chưa cấu hình danh mục bậc hạng (CapBacHang).",
            )

        base_username = email.split("@")[0][:40]
        unique_username = f"{base_username}_{uuid.uuid4().hex[:4]}"

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
                    1, SYSUTCDATETIME(), 'HOAT_DONG'
                )
            """),
            {
                "uid": firebase_uid,
                "username": unique_username,
                "email": email,
                "hoten": name,
                "avatar": picture,
                "mahang": ma_hang_mac_dinh,
            },
        )
        db.commit()
        user = db.execute(query_find, {"uid": firebase_uid}).mappings().first()
    else:
        db.execute(
            text("""
                UPDATE NguoiDung
                SET TrangThaiOnline = 1, HoatDongCuoi = SYSUTCDATETIME()
                WHERE MaNguoiDung = :id
            """),
            {"id": user["MaNguoiDung"]},
        )
        db.commit()

    if user["TrangThaiTaiKhoan"] != "HOAT_DONG":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Tài khoản bị khóa ({user['TrangThaiTaiKhoan']}): {user['LyDoKhoa'] or 'Liên hệ Admin'}",
        )

    return dict(user)


def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    if current_user["VaiTro"] != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ quản trị viên (ADMIN) mới có quyền thực hiện thao tác này.",
        )
    return current_user