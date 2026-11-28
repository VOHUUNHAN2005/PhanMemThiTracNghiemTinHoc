from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user

router = APIRouter(prefix="/api/leaderboard", tags=["Leaderboard"])


@router.get("")
def get_cup_leaderboard(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    top_rows = db.execute(
        text("""
            SELECT TOP 50
                u.MaNguoiDung,
                u.TenDangNhap,
                u.HoTen,
                u.AnhDaiDien,
                u.SoCupHienTai,
                u.TrangThaiOnline,
                h.TenHang,
                h.ThuTuHang
            FROM NguoiDung u
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE u.VaiTro = 'THI_SINH' AND u.TrangThaiTaiKhoan = 'HOAT_DONG'
            ORDER BY u.SoCupHienTai DESC, u.MaNguoiDung ASC
        """)
    ).mappings().all()

    my_rank = db.execute(
        text("""
            SELECT COUNT(*) + 1
            FROM NguoiDung
            WHERE VaiTro = 'THI_SINH'
              AND TrangThaiTaiKhoan = 'HOAT_DONG'
              AND SoCupHienTai > (SELECT ISNULL(SoCupHienTai, 0) FROM NguoiDung WHERE MaNguoiDung = :me)
        """),
        {"me": me_id},
    ).scalar()

    return {
        "HangCuaToi": my_rank,
        "SoCupCuaToi": current_user["SoCupHienTai"],
        "TenHangCuaToi": current_user["TenHang"],
        "TopNguoiChoi": [
            {
                "ThuHang": idx,
                "MaNguoiDung": r["MaNguoiDung"],
                "TenDangNhap": r["TenDangNhap"],
                "HoTen": r["HoTen"],
                "AnhDaiDien": r["AnhDaiDien"],
                "SoCupHienTai": r["SoCupHienTai"],
                "TenHang": r["TenHang"],
                "TrangThaiOnline": bool(r["TrangThaiOnline"]),
            }
            for idx, r in enumerate(top_rows, start=1)
        ],
    }