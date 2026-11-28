from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])


@router.get("")
def get_all_notifications(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    rows = db.execute(
        text("""
            SELECT TOP 50
                MaThongBao,
                LoaiThongBao,
                TieuDe,
                NoiDung,
                MaThamChieu,
                DaDoc,
                NgayTao
            FROM ThongBao
            WHERE MaNguoiNhan = :me
            ORDER BY NgayTao DESC, MaThongBao DESC
        """),
        {"me": me_id},
    ).mappings().all()

    unread_count = sum(1 for r in rows if not r["DaDoc"])

    return {
        "chua_doc": unread_count,
        "danh_sach": [
            {
                "MaThongBao": r["MaThongBao"],
                "LoaiThongBao": r["LoaiThongBao"],
                "TieuDe": r["TieuDe"],
                "NoiDung": r["NoiDung"],
                "MaThamChieu": r["MaThamChieu"],
                "DaDoc": bool(r["DaDoc"]),
                "NgayTao": r["NgayTao"].isoformat() if r["NgayTao"] else None,
            }
            for r in rows
        ],
    }


@router.put("/read-all")
def mark_all_notifications_read(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.execute(
        text("UPDATE ThongBao SET DaDoc = 1 WHERE MaNguoiNhan = :me AND DaDoc = 0"),
        {"me": current_user["MaNguoiDung"]},
    )
    db.commit()
    return {"message": "Đã đánh dấu tất cả thông báo là đã đọc."}