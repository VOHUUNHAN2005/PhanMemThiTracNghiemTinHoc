from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user

router = APIRouter(prefix="/api/favorites", tags=["Favorites"])


@router.post("/exams/{ma_bo_de}/toggle")
def toggle_favorite_exam(
    ma_bo_de: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    bo_de = db.execute(
        text("SELECT MaBoDe, TieuDe FROM BoDe WHERE MaBoDe = :id AND TrangThai = 'CONG_KHAI'"),
        {"id": ma_bo_de},
    ).mappings().first()

    if not bo_de:
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề hoặc bộ đề chưa công khai.")

    existing = db.execute(
        text("SELECT 1 FROM BoDeYeuThich WHERE MaNguoiDung = :me AND MaBoDe = :bo_de"),
        {"me": me_id, "bo_de": ma_bo_de},
    ).first()

    if existing:
        db.execute(
            text("DELETE FROM BoDeYeuThich WHERE MaNguoiDung = :me AND MaBoDe = :bo_de"),
            {"me": me_id, "bo_de": ma_bo_de},
        )
        db.commit()
        return {
            "MaBoDe": ma_bo_de,
            "is_favorite": False,
            "message": "Đã bỏ khỏi danh sách bộ đề yêu thích.",
        }

    db.execute(
        text("INSERT INTO BoDeYeuThich (MaNguoiDung, MaBoDe, NgayLuu) VALUES (:me, :bo_de, GETDATE())"),
        {"me": me_id, "bo_de": ma_bo_de},
    )
    db.commit()
    return {
        "MaBoDe": ma_bo_de,
        "is_favorite": True,
        "message": "Đã thêm vào danh sách bộ đề yêu thích!",
    }


@router.get("/me")
def get_my_favorite_exams_grouped_by_topic(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    rows = db.execute(
        text("""
            SELECT
                yt.MaBoDe,
                yt.NgayLuu,
                bd.TieuDe,
                bd.MoTa,
                bd.LoaiBoDe,
                bd.ThoiGianLamBai,
                bd.DiemDatToiThieu,
                ISNULL(cd.MaChuDe, 0) AS MaChuDe,
                ISNULL(cd.TenChuDe, N'Chủ đề chung') AS TenChuDe,
                cd.MoTa AS MoTaChuDe,
                (SELECT COUNT(*) FROM ChiTietBoDe ct WHERE ct.MaBoDe = bd.MaBoDe) AS SoLuongCauHoi,
                CAST(
                    CASE WHEN EXISTS (
                        SELECT 1 FROM LuotLamBai llb
                        WHERE llb.MaBoDe = bd.MaBoDe
                          AND llb.MaNguoiDung = :me
                          AND llb.DaDat = 1
                    ) THEN 1 ELSE 0 END AS BIT
                ) AS DaDat
            FROM BoDeYeuThich yt
            INNER JOIN BoDe bd ON yt.MaBoDe = bd.MaBoDe
            LEFT JOIN ChuDe cd ON bd.MaChuDe = cd.MaChuDe
            WHERE yt.MaNguoiDung = :me
              AND bd.TrangThai = 'CONG_KHAI'
            ORDER BY cd.TenChuDe ASC, yt.NgayLuu DESC
        """),
        {"me": me_id},
    ).mappings().all()

    favorite_ids = [r["MaBoDe"] for r in rows]
    topics_map: dict[int, dict] = {}

    for r in rows:
        cd_id = r["MaChuDe"]
        if cd_id not in topics_map:
            topics_map[cd_id] = {
                "MaChuDe": cd_id,
                "TenChuDe": r["TenChuDe"],
                "MoTa": r["MoTaChuDe"],
                "SoBoDeYeuThich": 0,
                "DanhSachBoDe": [],
            }

        topics_map[cd_id]["SoBoDeYeuThich"] += 1
        topics_map[cd_id]["DanhSachBoDe"].append({
            "MaBoDe": r["MaBoDe"],
            "TieuDe": r["TieuDe"],
            "MoTa": r["MoTa"],
            "LoaiBoDe": r["LoaiBoDe"],
            "ThoiGianLamBai": r["ThoiGianLamBai"],
            "DiemDatToiThieu": float(r["DiemDatToiThieu"]),
            "SoLuongCauHoi": r["SoLuongCauHoi"] or 0,
            "DaDat": bool(r["DaDat"]),
            "NgayLuu": r["NgayLuu"].isoformat() if r["NgayLuu"] else None,
        })

    return {
        "total_favorites": len(favorite_ids),
        "favorite_exam_ids": favorite_ids,
        "topics": list(topics_map.values()),
    }