from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user

router = APIRouter(prefix="/api/home", tags=["Home Topics & Official Exams"])


@router.get("/topics")
def get_home_topics(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
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
               AND bd.LoaiBoDe = 'THI_CHINH_THUC'
            LEFT JOIN LuotLamBai llb
                ON bd.MaBoDe = llb.MaBoDe
               AND llb.MaNguoiDung = :me
               AND llb.DaDat = 1
            GROUP BY cd.MaChuDe, cd.TenChuDe, cd.MoTa
            ORDER BY cd.MaChuDe ASC
        """),
        {"me": current_user["MaNguoiDung"]},
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


@router.get("/topics/{ma_chu_de}/exams")
def get_home_exams_by_topic(
    ma_chu_de: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
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
              AND bd.LoaiBoDe = 'THI_CHINH_THUC'
            ORDER BY bd.MaBoDe ASC
        """),
        {"ma_chu_de": ma_chu_de, "me": me_id},
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