from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user

router = APIRouter(prefix="/api", tags=["Home & Practice"])


def _query_topics_by_type(db: Session, me_id: int, loai_bo_de: str):
    rows = db.execute(
        text("""
            SELECT
                cd.MaChuDe,
                cd.TenChuDe,
                cd.MoTa,
                COUNT(DISTINCT bd.MaBoDe) AS TongSoBoDe,
                COUNT(DISTINCT CASE WHEN llb.DaDat = 1 THEN bd.MaBoDe END) AS SoBoDeDaDat
            FROM ChuDe cd
            LEFT JOIN BoDe bd
                ON cd.MaChuDe = bd.MaChuDe
               AND bd.TrangThai = 'CONG_KHAI'
               AND bd.LoaiBoDe = :loai
            LEFT JOIN LuotLamBai llb
                ON bd.MaBoDe = llb.MaBoDe
               AND llb.MaNguoiDung = :me
               AND llb.DaDat = 1
            GROUP BY cd.MaChuDe, cd.TenChuDe, cd.MoTa
            ORDER BY cd.MaChuDe ASC
        """),
        {"me": me_id, "loai": loai_bo_de},
    ).mappings().all()

    return [
        {
            "MaChuDe": r["MaChuDe"],
            "TenChuDe": r["TenChuDe"],
            "MoTa": r["MoTa"],
            "TongSoBoDe": r["TongSoBoDe"] or 0,
            "SoBoDeDaDat": r["SoBoDeDaDat"] or 0,
        }
        for r in rows
    ]


def _query_exams_by_topic_and_type(db: Session, me_id: int, ma_chu_de: int, loai_bo_de: str):
    topic = db.execute(
        text("SELECT MaChuDe, TenChuDe, MoTa FROM ChuDe WHERE MaChuDe = :id"),
        {"id": ma_chu_de},
    ).mappings().first()

    if not topic:
        raise HTTPException(status_code=404, detail="Không tìm thấy chủ đề.")

    rows = db.execute(
        text("""
            SELECT
                bd.MaBoDe,
                bd.TieuDe,
                bd.MoTa,
                bd.LoaiBoDe,
                bd.ThoiGianLamBai,
                bd.DiemDatToiThieu,
                (SELECT COUNT(*) FROM ChiTietBoDe ct WHERE ct.MaBoDe = bd.MaBoDe) AS SoLuongCauHoi,
                (
                    SELECT MAX(llb.DiemSo)
                    FROM LuotLamBai llb
                    WHERE llb.MaBoDe = bd.MaBoDe
                      AND llb.MaNguoiDung = :me
                      AND llb.TrangThai IN ('DA_NOP', 'HET_GIO')
                ) AS DiemCaoNhat,
                CAST(
                    CASE WHEN EXISTS (
                        SELECT 1 FROM LuotLamBai llb
                        WHERE llb.MaBoDe = bd.MaBoDe
                          AND llb.MaNguoiDung = :me
                          AND llb.DaDat = 1
                    ) THEN 1 ELSE 0 END AS BIT
                ) AS DaDat,
                (
                    SELECT TOP 1 llb.MaLuotLam
                    FROM LuotLamBai llb
                    WHERE llb.MaBoDe = bd.MaBoDe
                      AND llb.MaNguoiDung = :me
                      AND llb.TrangThai = 'DANG_LAM'
                ) AS MaLuotDangLam
            FROM BoDe bd
            WHERE bd.MaChuDe = :ma_chu_de
              AND bd.TrangThai = 'CONG_KHAI'
              AND bd.LoaiBoDe = :loai
            ORDER BY bd.MaBoDe ASC
        """),
        {"ma_chu_de": ma_chu_de, "me": me_id, "loai": loai_bo_de},
    ).mappings().all()

    return {
        "ChuDe": {
            "MaChuDe": topic["MaChuDe"],
            "TenChuDe": topic["TenChuDe"],
            "MoTa": topic["MoTa"],
        },
        "TongSoBoDe": len(rows),
        "DanhSachBoDe": [
            {
                "MaBoDe": r["MaBoDe"],
                "TieuDe": r["TieuDe"],
                "MoTa": r["MoTa"],
                "LoaiBoDe": r["LoaiBoDe"],
                "ThoiGianLamBai": r["ThoiGianLamBai"],
                "DiemDatToiThieu": float(r["DiemDatToiThieu"]),
                "SoLuongCauHoi": r["SoLuongCauHoi"] or 0,
                "DiemCaoNhat": float(r["DiemCaoNhat"]) if r["DiemCaoNhat"] is not None else None,
                "DaDat": bool(r["DaDat"]),
                "MaLuotDangLam": r["MaLuotDangLam"],
            }
            for r in rows
        ],
    }





@router.get("/home/topics")
def get_home_topics(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _query_topics_by_type(db, current_user["MaNguoiDung"], "THI_CHINH_THUC")


@router.get("/home/topics/{ma_chu_de}/exams")
def get_home_exams_by_topic(
    ma_chu_de: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _query_exams_by_topic_and_type(db, current_user["MaNguoiDung"], ma_chu_de, "THI_CHINH_THUC")





@router.get("/practice/topics")
def get_practice_topics(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _query_topics_by_type(db, current_user["MaNguoiDung"], "LUYEN_TAP")


@router.get("/practice/topics/{ma_chu_de}/exams")
def get_practice_exams_by_topic(
    ma_chu_de: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _query_exams_by_topic_and_type(db, current_user["MaNguoiDung"], ma_chu_de, "LUYEN_TAP")
