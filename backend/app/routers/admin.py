import os
import random
import shutil
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.arena_manager import arena_manager
from security import require_admin

router = APIRouter(
    prefix="/api/admin",
    tags=["Admin Management"],
    dependencies=[Depends(require_admin)],
)

ALLOWED_IMG_EXT = {".jpg", ".jpeg", ".png", ".webp"}

class UpdateUserStatusRequest(BaseModel):
    TrangThaiTaiKhoan: str = Field(..., pattern="^(HOAT_DONG|BI_KHOA)$")
    LyDoKhoa: Optional[str] = Field(None, max_length=30)


class UpdateUserRoleRequest(BaseModel):
    VaiTro: str = Field(..., pattern="^(THI_SINH|ADMIN)$")


class AdjustCupRequest(BaseModel):
    SoCupThayDoi: int = Field(..., ne=0, description="Số dương để cộng, số âm để trừ")
    MoTa: str = Field(..., min_length=3, max_length=300)


class TopicCreateUpdateRequest(BaseModel):
    TenChuDe: str = Field(..., min_length=2, max_length=150)
    MoTa: Optional[str] = Field(None, max_length=500)


class ExamCreateUpdateRequest(BaseModel):
    TieuDe: str = Field(..., min_length=3, max_length=200)
    MoTa: Optional[str] = Field(None, max_length=500)
    LoaiBoDe: str = Field(..., pattern="^(LUYEN_TAP|THI_CHINH_THUC)$")
    MaChuDe: Optional[int] = None
    ThoiGianLamBai: Optional[int] = Field(None, ge=0)
    DiemDatToiThieu: float = Field(5.0, ge=0, le=10)
    TrangThai: str = Field("NHAP", pattern="^(NHAP|CONG_KHAI|AN)$")


class AutoGenerateExamsRequest(BaseModel):
    MaChuDe: int
    LoaiBoDe: str = Field(..., pattern="^(LUYEN_TAP|THI_CHINH_THUC)$")
    TienToTieuDe: Optional[str] = Field(None, max_length=150)
    MoTa: Optional[str] = Field(None, max_length=500)
    SoLuongDe: int = Field(..., ge=1, le=50)
    SoCauDe: int = Field(0, ge=0, le=200)
    SoCauTrungBinh: int = Field(0, ge=0, le=200)
    SoCauKho: int = Field(0, ge=0, le=200)
    ThoiGianLamBai: Optional[int] = Field(None, ge=0)
    DiemDatToiThieu: float = Field(5.0, ge=0, le=10)
    TrangThai: str = Field("CONG_KHAI", pattern="^(NHAP|CONG_KHAI|AN)$")


class AnswerItemRequest(BaseModel):
    NoiDung: str = Field(..., min_length=1, max_length=1000)
    LaDapAnDung: bool = False
    ThuTuHienThi: int = Field(..., ge=1)


class QuestionCreateUpdateRequest(BaseModel):
    MaChuDe: int
    MaLoaiCauHoi: int
    NoiDung: str = Field(..., min_length=2)
    HinhAnhUrl: Optional[str] = Field(None, max_length=500)
    MucDo: str = Field("TRUNG_BINH", pattern="^(DE|TRUNG_BINH|KHO)$")
    TrangThai: str = Field("HOAT_DONG", pattern="^(HOAT_DONG|AN)$")
    DapAn: List[AnswerItemRequest] = Field(..., min_length=2)

@router.get("/question-types")
def get_question_types(db: Session = Depends(get_db)):
    rows = db.execute(
        text("SELECT MaLoaiCauHoi, TenLoai, ChoPhepNhieuDapAn, CoHinhAnh FROM LoaiCauHoi ORDER BY MaLoaiCauHoi")
    ).mappings().all()
    return [
        {
            "MaLoaiCauHoi": r["MaLoaiCauHoi"],
            "TenLoai": r["TenLoai"],
            "ChoPhepNhieuDapAn": bool(r["ChoPhepNhieuDapAn"]),
            "CoHinhAnh": bool(r["CoHinhAnh"]),
        }
        for r in rows
    ]


@router.get("/stats")
def get_admin_stats(db: Session = Depends(get_db)):
    stats = db.execute(
        text("""
            SELECT
                (SELECT COUNT(*) FROM NguoiDung WHERE VaiTro = 'THI_SINH') AS TongThiSinh,
                (SELECT COUNT(*) FROM NguoiDung WHERE TrangThaiOnline = 1) AS DangOnline,
                (SELECT COUNT(*) FROM ChuDe) AS TongChuDe,
                (SELECT COUNT(*) FROM BoDe WHERE LoaiBoDe = 'LUYEN_TAP') AS TongDeOnTap,
                (SELECT COUNT(*) FROM BoDe WHERE LoaiBoDe = 'THI_CHINH_THUC') AS TongDeThi,
                (SELECT COUNT(*) FROM CauHoi WHERE TrangThai = 'HOAT_DONG') AS TongCauHoi
        """)
    ).mappings().first()
    return dict(stats)


@router.get("/users")
def list_users(
    search: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    account_status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    conditions = ["1=1"]
    params = {}

    if search and search.strip():
        conditions.append("(u.HoTen LIKE :kw OR u.TenDangNhap LIKE :kw OR u.Email LIKE :kw)")
        params["kw"] = f"%{search.strip()}%"

    if role and role in ("THI_SINH", "ADMIN"):
        conditions.append("u.VaiTro = :role")
        params["role"] = role

    if account_status and account_status in ("HOAT_DONG", "BI_KHOA"):
        conditions.append("u.TrangThaiTaiKhoan = :st")
        params["st"] = account_status

    where_clause = " AND ".join(conditions)
    offset = (page - 1) * limit
    params["offset"] = offset
    params["limit"] = limit

    total = db.execute(
        text(f"SELECT COUNT(*) FROM NguoiDung u WHERE {where_clause}"),
        params,
    ).scalar()

    rows = db.execute(
        text(f"""
            SELECT
                u.MaNguoiDung, u.TenDangNhap, u.Email, u.HoTen, u.AnhDaiDien,
                u.VaiTro, u.SoCupHienTai, u.TrangThaiOnline, u.HoatDongCuoi,
                u.TrangThaiTaiKhoan, u.LyDoKhoa, u.NgayTao,
                h.TenHang
            FROM NguoiDung u
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE {where_clause}
            ORDER BY u.NgayTao DESC
            OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
        """),
        params,
    ).mappings().all()

    return {
        "total": total,
        "page": page,
        "limit": limit,
        "items": [
            {
                **dict(r),
                "TrangThaiOnline": bool(r["TrangThaiOnline"]),
            }
            for r in rows
        ],
    }


@router.patch("/users/{user_id}/status")
@router.post("/users/{user_id}/status")
def update_user_status(
    user_id: int,
    payload: UpdateUserStatusRequest,
    db: Session = Depends(get_db),
):
    try:
        ly_do = payload.LyDoKhoa if payload.TrangThaiTaiKhoan == "BI_KHOA" else None
        res = db.execute(
            text("""
                UPDATE NguoiDung
                SET TrangThaiTaiKhoan = :st,
                    LyDoKhoa = :ly_do,
                    TrangThaiOnline = CASE WHEN :st = 'BI_KHOA' THEN 0 ELSE TrangThaiOnline END
                WHERE MaNguoiDung = :id
            """),
            {"st": payload.TrangThaiTaiKhoan, "ly_do": ly_do, "id": user_id},
        )
        if res.rowcount == 0:
            raise HTTPException(status_code=404, detail="Không tìm thấy người dùng.")
        db.commit()
        return {"message": "Cập nhật trạng thái thành công."}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Lỗi SQL: {str(e)}")


@router.post("/users/{user_id}/adjust-cups")
def adjust_user_cups(
    user_id: int,
    payload: AdjustCupRequest,
    db: Session = Depends(get_db),
):
    try:
        user = db.execute(
            text("SELECT MaNguoiDung, SoCupHienTai FROM NguoiDung WHERE MaNguoiDung = :id"),
            {"id": user_id},
        ).mappings().first()

        if not user:
            raise HTTPException(status_code=404, detail="Không tìm thấy người dùng.")

        cup_truoc = int(user["SoCupHienTai"] or 0)
        cup_sau = max(0, cup_truoc + payload.SoCupThayDoi)
        thay_doi_thuc_te = cup_sau - cup_truoc

        if thay_doi_thuc_te == 0:
            raise HTTPException(
                status_code=400,
                detail="Người dùng đang có 0 cúp nên không thể trừ thêm.",
            )

        new_rank_id = db.execute(
            text("""
                SELECT TOP 1 MaHang
                FROM CapBacHang
                WHERE CupToiThieu <= :cup_sau
                ORDER BY CupToiThieu DESC, ThuTuHang DESC
            """),
            {"cup_sau": cup_sau},
        ).scalar() or 1

        db.execute(
            text("""
                UPDATE NguoiDung
                SET SoCupHienTai = :cup_sau,
                    MaHangHienTai = :ma_hang
                WHERE MaNguoiDung = :id
            """),
            {"cup_sau": cup_sau, "ma_hang": new_rank_id, "id": user_id},
        )

        db.execute(
            text("""
                INSERT INTO LichSuBienDongCup (
                    MaNguoiDung, LoaiBienDong, MaThamChieu,
                    SoCupThayDoi, SoCupTruoc, SoCupSau, MoTa, NgayTao
                )
                VALUES (
                    :id, 'ADMIN_DIEU_CHINH', NULL,
                    :delta, :truoc, :sau, :mota, GETDATE()
                )
            """),
            {
                "id": user_id,
                "delta": thay_doi_thuc_te,
                "truoc": cup_truoc,
                "sau": cup_sau,
                "mota": payload.MoTa.strip(),
            },
        )
        db.commit()

        return {
            "message": "Đã điều chỉnh số cúp thành công.",
            "SoCupTruoc": cup_truoc,
            "SoCupSau": cup_sau,
            "MaHangHienTai": new_rank_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Lỗi lưu biến động cúp: {str(e)}")


@router.get("/topics")
def list_admin_topics(db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT
                cd.MaChuDe, cd.TenChuDe, cd.MoTa, cd.NgayTao,
                (SELECT COUNT(*) FROM BoDe bd WHERE bd.MaChuDe = cd.MaChuDe AND bd.LoaiBoDe = 'LUYEN_TAP') AS SoDeOnTap,
                (SELECT COUNT(*) FROM BoDe bd WHERE bd.MaChuDe = cd.MaChuDe AND bd.LoaiBoDe = 'THI_CHINH_THUC') AS SoDeThi,
                (SELECT COUNT(*) FROM CauHoi ch WHERE ch.MaChuDe = cd.MaChuDe) AS SoCauHoi,
                (SELECT COUNT(*) FROM CauHoi ch WHERE ch.MaChuDe = cd.MaChuDe AND ch.MucDo = 'DE' AND ch.TrangThai = 'HOAT_DONG') AS SoCauDe,
                (SELECT COUNT(*) FROM CauHoi ch WHERE ch.MaChuDe = cd.MaChuDe AND ch.MucDo = 'TRUNG_BINH' AND ch.TrangThai = 'HOAT_DONG') AS SoCauTrungBinh,
                (SELECT COUNT(*) FROM CauHoi ch WHERE ch.MaChuDe = cd.MaChuDe AND ch.MucDo = 'KHO' AND ch.TrangThai = 'HOAT_DONG') AS SoCauKho
            FROM ChuDe cd
            ORDER BY cd.MaChuDe DESC
        """)
    ).mappings().all()
    return [dict(r) for r in rows]


@router.post("/topics", status_code=status.HTTP_201_CREATED)
def create_topic(payload: TopicCreateUpdateRequest, db: Session = Depends(get_db)):
    try:
        ma_chu_de = db.execute(
            text("""
                INSERT INTO ChuDe (TenChuDe, MoTa)
                OUTPUT INSERTED.MaChuDe
                VALUES (:ten, :mota)
            """),
            {"ten": payload.TenChuDe.strip(), "mota": payload.MoTa.strip() if payload.MoTa else None},
        ).scalar()
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Tên chủ đề này đã tồn tại.")

    return {"message": "Tạo chủ đề thành công.", "MaChuDe": ma_chu_de}


@router.put("/topics/{ma_chu_de}")
def update_topic(ma_chu_de: int, payload: TopicCreateUpdateRequest, db: Session = Depends(get_db)):
    try:
        res = db.execute(
            text("UPDATE ChuDe SET TenChuDe = :ten, MoTa = :mota WHERE MaChuDe = :id"),
            {
                "ten": payload.TenChuDe.strip(),
                "mota": payload.MoTa.strip() if payload.MoTa else None,
                "id": ma_chu_de,
            },
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Tên chủ đề này đã tồn tại.")

    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Không tìm thấy chủ đề.")

    return {"message": "Cập nhật chủ đề thành công."}


@router.delete("/topics/{ma_chu_de}")
def delete_topic(ma_chu_de: int, db: Session = Depends(get_db)):
    in_use = db.execute(
        text("""
            SELECT TOP 1 1 FROM BoDe WHERE MaChuDe = :id
            UNION ALL
            SELECT TOP 1 1 FROM CauHoi WHERE MaChuDe = :id
        """),
        {"id": ma_chu_de},
    ).first()

    if in_use:
        raise HTTPException(
            status_code=400,
            detail="Không thể xóa chủ đề đang chứa bộ đề hoặc câu hỏi.",
        )

    res = db.execute(text("DELETE FROM ChuDe WHERE MaChuDe = :id"), {"id": ma_chu_de})
    db.commit()

    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Không tìm thấy chủ đề.")

    return {"message": "Đã xóa chủ đề."}


def _validate_question_answers(db: Session, ma_loai_cau_hoi: int, dap_an_list: List[AnswerItemRequest]):
    loai = db.execute(
        text("SELECT ChoPhepNhieuDapAn FROM LoaiCauHoi WHERE MaLoaiCauHoi = :id"),
        {"id": ma_loai_cau_hoi},
    ).mappings().first()

    if not loai:
        raise HTTPException(status_code=400, detail="Loại câu hỏi không hợp lệ.")

    so_dap_an_dung = sum(1 for a in dap_an_list if a.LaDapAnDung)
    if so_dap_an_dung == 0:
        raise HTTPException(status_code=400, detail="Câu hỏi phải có ít nhất 1 đáp án đúng.")

    if not loai["ChoPhepNhieuDapAn"] and so_dap_an_dung > 1:
        raise HTTPException(status_code=400, detail="Loại câu hỏi này chỉ cho phép duy nhất 1 đáp án đúng.")


@router.get("/questions")
def list_question_bank(
    ma_chu_de: Optional[int] = Query(None),
    muc_do: Optional[str] = Query(None, pattern="^(DE|TRUNG_BINH|KHO)$"),
    trang_thai: Optional[str] = Query(None, pattern="^(HOAT_DONG|AN)$"),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(30, ge=1, le=200),
    db: Session = Depends(get_db),
):
    summary_cond = "WHERE TrangThai = 'HOAT_DONG'"
    summary_params = {}
    if ma_chu_de:
        summary_cond += " AND MaChuDe = :cd"
        summary_params["cd"] = ma_chu_de

    summary_row = db.execute(
        text(f"""
            SELECT
                COUNT(*) AS Tong,
                ISNULL(SUM(CASE WHEN MucDo = 'DE' THEN 1 ELSE 0 END), 0) AS De,
                ISNULL(SUM(CASE WHEN MucDo = 'TRUNG_BINH' THEN 1 ELSE 0 END), 0) AS TrungBinh,
                ISNULL(SUM(CASE WHEN MucDo = 'KHO' THEN 1 ELSE 0 END), 0) AS Kho
            FROM CauHoi
            {summary_cond}
        """),
        summary_params,
    ).mappings().first()

    conditions = ["1=1"]
    params = {}
    if ma_chu_de:
        conditions.append("ch.MaChuDe = :cd")
        params["cd"] = ma_chu_de
    if muc_do:
        conditions.append("ch.MucDo = :mucdo")
        params["mucdo"] = muc_do
    if trang_thai:
        conditions.append("ch.TrangThai = :st")
        params["st"] = trang_thai
    if search and search.strip():
        conditions.append("ch.NoiDung LIKE :kw")
        params["kw"] = f"%{search.strip()}%"

    where_clause = " AND ".join(conditions)
    total = db.execute(
        text(f"SELECT COUNT(*) FROM CauHoi ch WHERE {where_clause}"),
        params,
    ).scalar()

    params["offset"] = (page - 1) * limit
    params["limit"] = limit

    q_rows = db.execute(
        text(f"""
            SELECT
                ch.MaCauHoi, ch.MaChuDe, cd.TenChuDe,
                ch.MaLoaiCauHoi, lch.TenLoai, lch.ChoPhepNhieuDapAn,
                ch.NoiDung, ch.HinhAnhUrl, ch.MucDo, ch.TrangThai, ch.NgayTao,
                (SELECT COUNT(*) FROM ChiTietBoDe ct WHERE ct.MaCauHoi = ch.MaCauHoi) AS SoBoDeSuDung
            FROM CauHoi ch
            INNER JOIN ChuDe cd ON ch.MaChuDe = cd.MaChuDe
            INNER JOIN LoaiCauHoi lch ON ch.MaLoaiCauHoi = lch.MaLoaiCauHoi
            WHERE {where_clause}
            ORDER BY ch.MaCauHoi DESC
            OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
        """),
        params,
    ).mappings().all()

    items = []
    q_ids = [r["MaCauHoi"] for r in q_rows]
    answers_by_q = {qid: [] for qid in q_ids}

    if q_ids:
        placeholders = ", ".join([f":id_{i}" for i in range(len(q_ids))])
        ans_params = {f"id_{i}": qid for i, qid in enumerate(q_ids)}
        ans_rows = db.execute(
            text(f"""
                SELECT MaDapAn, MaCauHoi, NoiDung, LaDapAnDung, ThuTuHienThi
                FROM DapAn
                WHERE MaCauHoi IN ({placeholders})
                ORDER BY ThuTuHienThi ASC
            """),
            ans_params,
        ).mappings().all()

        for a in ans_rows:
            answers_by_q[a["MaCauHoi"]].append({
                "MaDapAn": a["MaDapAn"],
                "NoiDung": a["NoiDung"],
                "LaDapAnDung": bool(a["LaDapAnDung"]),
                "ThuTuHienThi": a["ThuTuHienThi"],
            })

    for r in q_rows:
        qid = r["MaCauHoi"]
        items.append({
            **dict(r),
            "ChoPhepNhieuDapAn": bool(r["ChoPhepNhieuDapAn"]),
            "DapAn": answers_by_q.get(qid, []),
        })

    return {
        "total": total,
        "page": page,
        "limit": limit,
        "summary": dict(summary_row) if summary_row else {"Tong": 0, "De": 0, "TrungBinh": 0, "Kho": 0},
        "items": items,
    }


@router.post("/questions", status_code=status.HTTP_201_CREATED)
def create_question_in_bank(
    payload: QuestionCreateUpdateRequest,
    db: Session = Depends(get_db),
):
    topic_exists = db.execute(
        text("SELECT 1 FROM ChuDe WHERE MaChuDe = :id"),
        {"id": payload.MaChuDe},
    ).first()
    if not topic_exists:
        raise HTTPException(status_code=404, detail="Không tìm thấy chủ đề.")

    _validate_question_answers(db, payload.MaLoaiCauHoi, payload.DapAn)

    try:
        ma_cau_hoi = db.execute(
            text("""
                INSERT INTO CauHoi (MaChuDe, MaLoaiCauHoi, NoiDung, HinhAnhUrl, MucDo, TrangThai)
                OUTPUT INSERTED.MaCauHoi
                VALUES (:cd, :loai, :nd, :img, :mucdo, :st)
            """),
            {
                "cd": payload.MaChuDe,
                "loai": payload.MaLoaiCauHoi,
                "nd": payload.NoiDung.strip(),
                "img": payload.HinhAnhUrl,
                "mucdo": payload.MucDo,
                "st": payload.TrangThai,
            },
        ).scalar()

        for ans in payload.DapAn:
            db.execute(
                text("""
                    INSERT INTO DapAn (MaCauHoi, NoiDung, LaDapAnDung, ThuTuHienThi)
                    VALUES (:ch_id, :nd, :dung, :thutu)
                """),
                {
                    "ch_id": ma_cau_hoi,
                    "nd": ans.NoiDung.strip(),
                    "dung": 1 if ans.LaDapAnDung else 0,
                    "thutu": ans.ThuTuHienThi,
                },
            )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Lỗi khi lưu câu hỏi vào ngân hàng: {str(e)}")

    return {"message": "Đã thêm câu hỏi vào ngân hàng.", "MaCauHoi": ma_cau_hoi}


@router.delete("/questions/{ma_cau_hoi}")
def delete_question_from_bank(ma_cau_hoi: int, db: Session = Depends(get_db)):
    in_exam = db.execute(
        text("SELECT TOP 1 1 FROM ChiTietBoDe WHERE MaCauHoi = :id"),
        {"id": ma_cau_hoi},
    ).first()
    if in_exam:
        raise HTTPException(
            status_code=400,
            detail="Câu hỏi này đang nằm trong bộ đề. Hãy gỡ khỏi bộ đề trước khi xóa vĩnh viễn.",
        )

    has_history = db.execute(
        text("SELECT TOP 1 1 FROM ChiTietTraLoiLuotLam WHERE MaCauHoi = :id"),
        {"id": ma_cau_hoi},
    ).first()
    if has_history:
        raise HTTPException(
            status_code=400,
            detail="Câu hỏi đã có lịch sử thí sinh làm bài, không thể xóa. Hãy chuyển trạng thái sang Ẩn (AN).",
        )

    db.execute(text("DELETE FROM DapAn WHERE MaCauHoi = :id"), {"id": ma_cau_hoi})
    res = db.execute(text("DELETE FROM CauHoi WHERE MaCauHoi = :id"), {"id": ma_cau_hoi})
    db.commit()

    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Không tìm thấy câu hỏi.")

    return {"message": "Đã xóa câu hỏi khỏi ngân hàng."}


@router.get("/exams")
def list_admin_exams(
    loai_bo_de: Optional[str] = Query(None, pattern="^(LUYEN_TAP|THI_CHINH_THUC)$"),
    ma_chu_de: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    conditions = ["1=1"]
    params = {}

    if loai_bo_de:
        conditions.append("bd.LoaiBoDe = :loai")
        params["loai"] = loai_bo_de
    if ma_chu_de:
        conditions.append("bd.MaChuDe = :cd")
        params["cd"] = ma_chu_de

    rows = db.execute(
        text(f"""
            SELECT
                bd.MaBoDe, bd.TieuDe, bd.MoTa, bd.LoaiBoDe,
                bd.MaChuDe, cd.TenChuDe,
                bd.ThoiGianLamBai, bd.DiemDatToiThieu, bd.TrangThai, bd.NgayTao,
                (SELECT COUNT(*) FROM ChiTietBoDe ct WHERE ct.MaBoDe = bd.MaBoDe) AS SoCauHoi,
                (
                    SELECT COUNT(*)
                    FROM ChiTietBoDe ct
                    INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
                    WHERE ct.MaBoDe = bd.MaBoDe AND ch.MucDo = 'DE'
                ) AS SoCauDe,
                (
                    SELECT COUNT(*)
                    FROM ChiTietBoDe ct
                    INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
                    WHERE ct.MaBoDe = bd.MaBoDe AND ch.MucDo = 'TRUNG_BINH'
                ) AS SoCauTrungBinh,
                (
                    SELECT COUNT(*)
                    FROM ChiTietBoDe ct
                    INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
                    WHERE ct.MaBoDe = bd.MaBoDe AND ch.MucDo = 'KHO'
                ) AS SoCauKho,
                (SELECT COUNT(*) FROM DanhGiaBoDe dg WHERE dg.MaBoDe = bd.MaBoDe) AS SoDanhGia,
                (SELECT CAST(AVG(CAST(dg.SoSao AS FLOAT)) AS DECIMAL(3,1)) FROM DanhGiaBoDe dg WHERE dg.MaBoDe = bd.MaBoDe) AS DiemDoKhoTrungBinh
            FROM BoDe bd
            LEFT JOIN ChuDe cd ON bd.MaChuDe = cd.MaChuDe
            WHERE {" AND ".join(conditions)}
            ORDER BY bd.NgayTao DESC, bd.MaBoDe DESC
        """),
        params,
    ).mappings().all()

    return [
        {
            **dict(r),
            "DiemDatToiThieu": float(r["DiemDatToiThieu"]),
            "DiemDoKhoTrungBinh": float(r["DiemDoKhoTrungBinh"]) if r["DiemDoKhoTrungBinh"] is not None else None,
        }
        for r in rows
    ]


@router.post("/exams/auto-generate", status_code=status.HTTP_201_CREATED)
def auto_generate_exams(
    payload: AutoGenerateExamsRequest,
    db: Session = Depends(get_db),
):
    tong_moi_de = payload.SoCauDe + payload.SoCauTrungBinh + payload.SoCauKho
    if tong_moi_de <= 0:
        raise HTTPException(
            status_code=400,
            detail="Tổng số câu hỏi mỗi đề phải lớn hơn 0.",
        )

    if payload.LoaiBoDe == "THI_CHINH_THUC" and (not payload.ThoiGianLamBai or payload.ThoiGianLamBai <= 0):
        raise HTTPException(
            status_code=400,
            detail="Đề thi chính thức bắt buộc phải có thời gian làm bài lớn hơn 0 phút.",
        )

    topic = db.execute(
        text("SELECT MaChuDe, TenChuDe FROM ChuDe WHERE MaChuDe = :id"),
        {"id": payload.MaChuDe},
    ).mappings().first()
    if not topic:
        raise HTTPException(status_code=404, detail="Không tìm thấy chủ đề được chọn.")


    easy_ids = [
        r[0]
        for r in db.execute(
            text("SELECT MaCauHoi FROM CauHoi WHERE MaChuDe = :cd AND TrangThai = 'HOAT_DONG' AND MucDo = 'DE'"),
            {"cd": payload.MaChuDe},
        ).all()
    ]
    medium_ids = [
        r[0]
        for r in db.execute(
            text("SELECT MaCauHoi FROM CauHoi WHERE MaChuDe = :cd AND TrangThai = 'HOAT_DONG' AND MucDo = 'TRUNG_BINH'"),
            {"cd": payload.MaChuDe},
        ).all()
    ]
    hard_ids = [
        r[0]
        for r in db.execute(
            text("SELECT MaCauHoi FROM CauHoi WHERE MaChuDe = :cd AND TrangThai = 'HOAT_DONG' AND MucDo = 'KHO'"),
            {"cd": payload.MaChuDe},
        ).all()
    ]


    if payload.LoaiBoDe == "LUYEN_TAP":

        req_easy = payload.SoLuongDe * payload.SoCauDe
        req_med = payload.SoLuongDe * payload.SoCauTrungBinh
        req_hard = payload.SoLuongDe * payload.SoCauKho

        if len(easy_ids) < req_easy:
            raise HTTPException(
                status_code=400,
                detail=f"Không đủ câu hỏi Dễ để chia đều {payload.SoLuongDe} đề ôn (Cần {req_easy}, kho có {len(easy_ids)}).",
            )
        if len(medium_ids) < req_med:
            raise HTTPException(
                status_code=400,
                detail=f"Không đủ câu hỏi Trung bình để chia đều {payload.SoLuongDe} đề ôn (Cần {req_med}, kho có {len(medium_ids)}).",
            )
        if len(hard_ids) < req_hard:
            raise HTTPException(
                status_code=400,
                detail=f"Không đủ câu hỏi Khó để chia đều {payload.SoLuongDe} đề ôn (Cần {req_hard}, kho có {len(hard_ids)}).",
            )

        random.shuffle(easy_ids)
        random.shuffle(medium_ids)
        random.shuffle(hard_ids)
    else:
        if len(easy_ids) < payload.SoCauDe:
            raise HTTPException(
                status_code=400,
                detail=f"Kho chỉ có {len(easy_ids)} câu Dễ, không đủ {payload.SoCauDe} câu/đề.",
            )
        if len(medium_ids) < payload.SoCauTrungBinh:
            raise HTTPException(
                status_code=400,
                detail=f"Kho chỉ có {len(medium_ids)} câu Trung bình, không đủ {payload.SoCauTrungBinh} câu/đề.",
            )
        if len(hard_ids) < payload.SoCauKho:
            raise HTTPException(
                status_code=400,
                detail=f"Kho chỉ có {len(hard_ids)} câu Khó, không đủ {payload.SoCauKho} câu/đề.",
            )

    default_prefix = (
        f"Ôn tập {topic['TenChuDe']}"
        if payload.LoaiBoDe == "LUYEN_TAP"
        else f"Đề thi {topic['TenChuDe']}"
    )
    prefix = (payload.TienToTieuDe or "").strip() or default_prefix
    thoi_gian = None if payload.LoaiBoDe == "LUYEN_TAP" else payload.ThoiGianLamBai

    created_exams = []
    try:
        for idx in range(payload.SoLuongDe):
            if payload.LoaiBoDe == "LUYEN_TAP":
                picked_easy = easy_ids[idx * payload.SoCauDe : (idx + 1) * payload.SoCauDe]
                picked_med = medium_ids[idx * payload.SoCauTrungBinh : (idx + 1) * payload.SoCauTrungBinh]
                picked_hard = hard_ids[idx * payload.SoCauKho : (idx + 1) * payload.SoCauKho]
            else:
                picked_easy = random.sample(easy_ids, payload.SoCauDe) if payload.SoCauDe > 0 else []
                picked_med = random.sample(medium_ids, payload.SoCauTrungBinh) if payload.SoCauTrungBinh > 0 else []
                picked_hard = random.sample(hard_ids, payload.SoCauKho) if payload.SoCauKho > 0 else []

            selected_q_ids = picked_easy + picked_med + picked_hard
            random.shuffle(selected_q_ids)

            tieu_de = f"{prefix} - Đề {idx + 1:02d}"
            ma_bo_de = db.execute(
                text("""
                    INSERT INTO BoDe (
                        TieuDe, MoTa, LoaiBoDe, MaChuDe,
                        ThoiGianLamBai, DiemDatToiThieu, TrangThai
                    )
                    OUTPUT INSERTED.MaBoDe
                    VALUES (
                        :tieude, :mota, :loai, :machude,
                        :thoigian, :diemdat, :trangthai
                    )
                """),
                {
                    "tieude": tieu_de,
                    "mota": payload.MoTa.strip() if payload.MoTa else None,
                    "loai": payload.LoaiBoDe,
                    "machude": payload.MaChuDe,
                    "thoigian": thoi_gian,
                    "diemdat": payload.DiemDatToiThieu,
                    "trangthai": payload.TrangThai,
                },
            ).scalar()

            for order_idx, q_id in enumerate(selected_q_ids, start=1):
                db.execute(
                    text("""
                        INSERT INTO ChiTietBoDe (MaBoDe, MaCauHoi, ThuTuCau)
                        VALUES (:bo_de, :ch_id, :thutu)
                    """),
                    {"bo_de": ma_bo_de, "ch_id": q_id, "thutu": order_idx},
                )

            created_exams.append({"MaBoDe": ma_bo_de, "TieuDe": tieu_de})

        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Lỗi khi sinh bộ đề tự động: {str(e)}")

    return {
        "message": f"Đã sinh thành công {len(created_exams)} bộ đề ({tong_moi_de} câu/đề).",
        "items": created_exams,
    }


@router.post("/exams", status_code=status.HTTP_201_CREATED)
def create_exam(payload: ExamCreateUpdateRequest, db: Session = Depends(get_db)):
    if payload.LoaiBoDe == "THI_CHINH_THUC" and (not payload.ThoiGianLamBai or payload.ThoiGianLamBai <= 0):
        raise HTTPException(
            status_code=400,
            detail="Đề thi chính thức bắt buộc phải có thời gian làm bài lớn hơn 0 phút.",
        )

    ma_bo_de = db.execute(
        text("""
            INSERT INTO BoDe (
                TieuDe, MoTa, LoaiBoDe, MaChuDe,
                ThoiGianLamBai, DiemDatToiThieu, TrangThai
            )
            OUTPUT INSERTED.MaBoDe
            VALUES (
                :tieude, :mota, :loai, :machude,
                :thoigian, :diemdat, :trangthai
            )
        """),
        {
            "tieude": payload.TieuDe.strip(),
            "mota": payload.MoTa.strip() if payload.MoTa else None,
            "loai": payload.LoaiBoDe,
            "machude": payload.MaChuDe,
            "thoigian": payload.ThoiGianLamBai,
            "diemdat": payload.DiemDatToiThieu,
            "trangthai": payload.TrangThai,
        },
    ).scalar()
    db.commit()

    return {"message": "Tạo bộ đề thành công.", "MaBoDe": ma_bo_de}


@router.put("/exams/{ma_bo_de}")
def update_exam(ma_bo_de: int, payload: ExamCreateUpdateRequest, db: Session = Depends(get_db)):
    if payload.LoaiBoDe == "THI_CHINH_THUC" and (not payload.ThoiGianLamBai or payload.ThoiGianLamBai <= 0):
        raise HTTPException(
            status_code=400,
            detail="Đề thi chính thức bắt buộc phải có thời gian làm bài lớn hơn 0 phút.",
        )

    res = db.execute(
        text("""
            UPDATE BoDe
            SET TieuDe = :tieude,
                MoTa = :mota,
                LoaiBoDe = :loai,
                MaChuDe = :machude,
                ThoiGianLamBai = :thoigian,
                DiemDatToiThieu = :diemdat,
                TrangThai = :trangthai
            WHERE MaBoDe = :id
        """),
        {
            "tieude": payload.TieuDe.strip(),
            "mota": payload.MoTa.strip() if payload.MoTa else None,
            "loai": payload.LoaiBoDe,
            "machude": payload.MaChuDe,
            "thoigian": payload.ThoiGianLamBai,
            "diemdat": payload.DiemDatToiThieu,
            "trangthai": payload.TrangThai,
            "id": ma_bo_de,
        },
    )
    db.commit()

    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề.")

    return {"message": "Cập nhật bộ đề thành công."}


@router.delete("/exams/{ma_bo_de}")
def delete_exam(ma_bo_de: int, db: Session = Depends(get_db)):
    has_attempts = db.execute(
        text("SELECT TOP 1 1 FROM LuotLamBai WHERE MaBoDe = :id"),
        {"id": ma_bo_de},
    ).first()

    if has_attempts:
        raise HTTPException(
            status_code=400,
            detail="Bộ đề đã có thí sinh làm bài, không thể xóa vĩnh viễn. Hãy chuyển trạng thái sang Ẩn (AN).",
        )

    db.execute(text("DELETE FROM ChiTietBoDe WHERE MaBoDe = :id"), {"id": ma_bo_de})
    res = db.execute(text("DELETE FROM BoDe WHERE MaBoDe = :id"), {"id": ma_bo_de})
    db.commit()

    if res.rowcount == 0:
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề.")

    return {"message": "Đã xóa bộ đề."}


@router.post("/questions/upload-image")
def upload_question_image(request: Request, file: UploadFile = File(...)):
    ext = os.path.splitext(file.filename or "q.png")[1].lower()
    if ext not in ALLOWED_IMG_EXT:
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận ảnh JPG, JPEG, PNG, WEBP.")

    os.makedirs("static/questions", exist_ok=True)
    filename = f"q_{uuid.uuid4().hex[:12]}{ext}"
    file_path = os.path.join("static", "questions", filename)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    finally:
        file.file.close()

    base_url = str(request.base_url).rstrip("/")
    return {"HinhAnhUrl": f"{base_url}/static/questions/{filename}"}


@router.get("/exams/{ma_bo_de}/questions")
def get_exam_questions_for_admin(ma_bo_de: int, db: Session = Depends(get_db)):
    rows = db.execute(
        text("""
            SELECT
                ct.ThuTuCau,
                ch.MaCauHoi, ch.MaChuDe, ch.MaLoaiCauHoi,
                ch.NoiDung AS NoiDungCauHoi, ch.HinhAnhUrl,
                ch.MucDo, ch.TrangThai,
                lch.TenLoai, lch.ChoPhepNhieuDapAn,
                da.MaDapAn, da.NoiDung AS NoiDungDapAn,
                da.LaDapAnDung, da.ThuTuHienThi
            FROM ChiTietBoDe ct
            INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
            INNER JOIN LoaiCauHoi lch ON ch.MaLoaiCauHoi = lch.MaLoaiCauHoi
            LEFT JOIN DapAn da ON ch.MaCauHoi = da.MaCauHoi
            WHERE ct.MaBoDe = :bo_de
            ORDER BY ct.ThuTuCau ASC, da.ThuTuHienThi ASC
        """),
        {"bo_de": ma_bo_de},
    ).mappings().all()

    questions_map = {}
    for r in rows:
        q_id = r["MaCauHoi"]
        if q_id not in questions_map:
            questions_map[q_id] = {
                "ThuTuCau": r["ThuTuCau"],
                "MaCauHoi": q_id,
                "MaChuDe": r["MaChuDe"],
                "MaLoaiCauHoi": r["MaLoaiCauHoi"],
                "TenLoai": r["TenLoai"],
                "ChoPhepNhieuDapAn": bool(r["ChoPhepNhieuDapAn"]),
                "NoiDung": r["NoiDungCauHoi"],
                "HinhAnhUrl": r["HinhAnhUrl"],
                "MucDo": r["MucDo"],
                "TrangThai": r["TrangThai"],
                "DapAn": [],
            }
        if r["MaDapAn"] is not None:
            questions_map[q_id]["DapAn"].append({
                "MaDapAn": r["MaDapAn"],
                "NoiDung": r["NoiDungDapAn"],
                "LaDapAnDung": bool(r["LaDapAnDung"]),
                "ThuTuHienThi": r["ThuTuHienThi"],
            })

    return list(questions_map.values())


@router.post("/exams/{ma_bo_de}/questions", status_code=status.HTTP_201_CREATED)
def create_question_in_exam(
    ma_bo_de: int,
    payload: QuestionCreateUpdateRequest,
    db: Session = Depends(get_db),
):
    bo_de = db.execute(
        text("SELECT MaBoDe, MaChuDe FROM BoDe WHERE MaBoDe = :id"),
        {"id": ma_bo_de},
    ).mappings().first()
    if not bo_de:
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề.")

    _validate_question_answers(db, payload.MaLoaiCauHoi, payload.DapAn)

    try:
        ma_cau_hoi = db.execute(
            text("""
                INSERT INTO CauHoi (MaChuDe, MaLoaiCauHoi, NoiDung, HinhAnhUrl, MucDo, TrangThai)
                OUTPUT INSERTED.MaCauHoi
                VALUES (:cd, :loai, :nd, :img, :mucdo, :st)
            """),
            {
                "cd": payload.MaChuDe,
                "loai": payload.MaLoaiCauHoi,
                "nd": payload.NoiDung.strip(),
                "img": payload.HinhAnhUrl,
                "mucdo": payload.MucDo,
                "st": payload.TrangThai,
            },
        ).scalar()

        for ans in payload.DapAn:
            db.execute(
                text("""
                    INSERT INTO DapAn (MaCauHoi, NoiDung, LaDapAnDung, ThuTuHienThi)
                    VALUES (:ch_id, :nd, :dung, :thutu)
                """),
                {
                    "ch_id": ma_cau_hoi,
                    "nd": ans.NoiDung.strip(),
                    "dung": 1 if ans.LaDapAnDung else 0,
                    "thutu": ans.ThuTuHienThi,
                },
            )

        next_order = db.execute(
            text("SELECT ISNULL(MAX(ThuTuCau), 0) + 1 FROM ChiTietBoDe WHERE MaBoDe = :id"),
            {"id": ma_bo_de},
        ).scalar()

        db.execute(
            text("""
                INSERT INTO ChiTietBoDe (MaBoDe, MaCauHoi, ThuTuCau)
                VALUES (:bo_de, :ch_id, :thutu)
            """),
            {"bo_de": ma_bo_de, "ch_id": ma_cau_hoi, "thutu": next_order},
        )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Lỗi khi lưu câu hỏi: {str(e)}")

    return {"message": "Thêm câu hỏi thành công.", "MaCauHoi": ma_cau_hoi}


@router.post("/exams/{ma_bo_de}/questions/{ma_cau_hoi}/swap")
def swap_question_in_exam(
    ma_bo_de: int,
    ma_cau_hoi: int,
    db: Session = Depends(get_db),
):
    current_q = db.execute(
        text("""
            SELECT ct.ThuTuCau, ch.MaChuDe, ch.MucDo
            FROM ChiTietBoDe ct
            INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
            WHERE ct.MaBoDe = :bo_de AND ct.MaCauHoi = :ch_id
        """),
        {"bo_de": ma_bo_de, "ch_id": ma_cau_hoi},
    ).mappings().first()

    if not current_q:
        raise HTTPException(status_code=404, detail="Không tìm thấy câu hỏi trong bộ đề này.")

    replacement_id = db.execute(
        text("""
            SELECT TOP 1 ch.MaCauHoi
            FROM CauHoi ch
            WHERE ch.MaChuDe = :cd
              AND ch.MucDo = :mucdo
              AND ch.TrangThai = 'HOAT_DONG'
              AND ch.MaCauHoi NOT IN (
                  SELECT MaCauHoi FROM ChiTietBoDe WHERE MaBoDe = :bo_de
              )
            ORDER BY NEWID()
        """),
        {
            "cd": current_q["MaChuDe"],
            "mucdo": current_q["MucDo"],
            "bo_de": ma_bo_de,
        },
    ).scalar()

    if not replacement_id:
        raise HTTPException(
            status_code=400,
            detail="Không còn câu hỏi dự phòng nào khác cùng chủ đề và cùng mức độ trong kho.",
        )

    db.execute(
        text("""
            UPDATE ChiTietBoDe
            SET MaCauHoi = :new_id
            WHERE MaBoDe = :bo_de AND MaCauHoi = :old_id
        """),
        {"new_id": replacement_id, "bo_de": ma_bo_de, "old_id": ma_cau_hoi},
    )
    db.commit()

    return {"message": "Đã tráo đổi sang câu hỏi khác cùng mức độ.", "MaCauHoiMoi": replacement_id}


@router.put("/questions/{ma_cau_hoi}")
def update_question(
    ma_cau_hoi: int,
    payload: QuestionCreateUpdateRequest,
    db: Session = Depends(get_db),
):
    exists = db.execute(
        text("SELECT 1 FROM CauHoi WHERE MaCauHoi = :id"),
        {"id": ma_cau_hoi},
    ).first()
    if not exists:
        raise HTTPException(status_code=404, detail="Không tìm thấy câu hỏi.")

    _validate_question_answers(db, payload.MaLoaiCauHoi, payload.DapAn)

    try:
        db.execute(
            text("""
                UPDATE CauHoi
                SET MaChuDe = :cd,
                    MaLoaiCauHoi = :loai,
                    NoiDung = :nd,
                    HinhAnhUrl = :img,
                    MucDo = :mucdo,
                    TrangThai = :st
                WHERE MaCauHoi = :id
            """),
            {
                "cd": payload.MaChuDe,
                "loai": payload.MaLoaiCauHoi,
                "nd": payload.NoiDung.strip(),
                "img": payload.HinhAnhUrl,
                "mucdo": payload.MucDo,
                "st": payload.TrangThai,
                "id": ma_cau_hoi,
            },
        )

        db.execute(text("DELETE FROM DapAn WHERE MaCauHoi = :id"), {"id": ma_cau_hoi})
        for ans in payload.DapAn:
            db.execute(
                text("""
                    INSERT INTO DapAn (MaCauHoi, NoiDung, LaDapAnDung, ThuTuHienThi)
                    VALUES (:ch_id, :nd, :dung, :thutu)
                """),
                {
                    "ch_id": ma_cau_hoi,
                    "nd": ans.NoiDung.strip(),
                    "dung": 1 if ans.LaDapAnDung else 0,
                    "thutu": ans.ThuTuHienThi,
                },
            )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail="Không thể sửa danh sách đáp án vì câu hỏi này đã có dữ liệu thí sinh trả lời.",
        )

    return {"message": "Cập nhật câu hỏi thành công."}


@router.delete("/exams/{ma_bo_de}/questions/{ma_cau_hoi}")
def remove_question_from_exam(
    ma_bo_de: int,
    ma_cau_hoi: int,
    db: Session = Depends(get_db),
):
    db.execute(
        text("DELETE FROM ChiTietBoDe WHERE MaBoDe = :bo_de AND MaCauHoi = :ch_id"),
        {"bo_de": ma_bo_de, "ch_id": ma_cau_hoi},
    )

    used_elsewhere = db.execute(
        text("""
            SELECT TOP 1 1 FROM ChiTietBoDe WHERE MaCauHoi = :ch_id
            UNION ALL
            SELECT TOP 1 1 FROM ChiTietTraLoiLuotLam WHERE MaCauHoi = :ch_id
        """),
        {"ch_id": ma_cau_hoi},
    ).first()

    if not used_elsewhere:
        db.execute(text("DELETE FROM DapAn WHERE MaCauHoi = :ch_id"), {"ch_id": ma_cau_hoi})
        db.execute(text("DELETE FROM CauHoi WHERE MaCauHoi = :ch_id"), {"ch_id": ma_cau_hoi})

    db.commit()
    return {"message": "Đã xóa câu hỏi khỏi bộ đề."}
class AttachQuestionsRequest(BaseModel):
    MaCauHoiList: List[int] = Field(..., min_length=1)


@router.post("/exams/{ma_bo_de}/questions/attach", status_code=status.HTTP_201_CREATED)
def attach_existing_questions_to_exam(
    ma_bo_de: int,
    payload: AttachQuestionsRequest,
    db: Session = Depends(get_db),
):
    bo_de = db.execute(
        text("SELECT MaBoDe FROM BoDe WHERE MaBoDe = :id"),
        {"id": ma_bo_de},
    ).first()
    if not bo_de:
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề.")

    existing_ids = {
        r[0]
        for r in db.execute(
            text("SELECT MaCauHoi FROM ChiTietBoDe WHERE MaBoDe = :id"),
            {"id": ma_bo_de},
        ).all()
    }

    next_order = db.execute(
        text("SELECT ISNULL(MAX(ThuTuCau), 0) + 1 FROM ChiTietBoDe WHERE MaBoDe = :id"),
        {"id": ma_bo_de},
    ).scalar()

    added_count = 0
    try:
        for q_id in dict.fromkeys(payload.MaCauHoiList):
            if q_id in existing_ids:
                continue
            q_exists = db.execute(
                text("SELECT 1 FROM CauHoi WHERE MaCauHoi = :qid AND TrangThai = 'HOAT_DONG'"),
                {"qid": q_id},
            ).first()
            if q_exists:
                db.execute(
                    text("""
                        INSERT INTO ChiTietBoDe (MaBoDe, MaCauHoi, ThuTuCau)
                        VALUES (:bo_de, :ch_id, :thutu)
                    """),
                    {"bo_de": ma_bo_de, "ch_id": q_id, "thutu": next_order},
                )
                next_order += 1
                added_count += 1
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Lỗi khi thêm câu hỏi từ ngân hàng: {str(e)}")

    return {
        "message": f"Đã thêm {added_count} câu hỏi từ ngân hàng vào bộ đề.",
        "added": added_count,
    }


@router.get("/users/{user_id}/activity")
def get_user_activity_history(user_id: int, db: Session = Depends(get_db)):
    user = db.execute(
        text("""
            SELECT
                u.MaNguoiDung,
                u.HoTen,
                u.Email,
                u.SoCupHienTai,
                u.MaHangHienTai,
                h.TenHang,
                h.ThuTuHang,
                u.TrangThaiTaiKhoan,
                u.VaiTro
            FROM NguoiDung u
            LEFT JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE u.MaNguoiDung = :uid
        """),
        {"uid": user_id},
    ).mappings().first()

    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng.")

    attempts = db.execute(
        text("""
            SELECT
                l.MaLuotLam,
                l.MaBoDe,
                b.TieuDe AS TenBoDe,
                b.LoaiBoDe,
                c.TenChuDe,
                l.ThoiGianBatDau,
                l.ThoiGianNopBai,
                DATEDIFF(SECOND, l.ThoiGianBatDau, ISNULL(l.ThoiGianNopBai, GETDATE())) AS ThoiGianLamGiay,
                l.TrangThai,
                l.SoCauDung,
                l.TongSoCau,
                l.DiemSo,
                l.DaDat,
                l.DaNhanCup
            FROM LuotLamBai l
            INNER JOIN BoDe b ON l.MaBoDe = b.MaBoDe
            LEFT JOIN ChuDe c ON b.MaChuDe = c.MaChuDe
            WHERE l.MaNguoiDung = :uid
            ORDER BY l.ThoiGianBatDau DESC
        """),
        {"uid": user_id},
    ).mappings().all()

    attempt_list = []
    completed_scores = []
    passed_count = 0
    practice_count = 0
    exam_count = 0

    for a in attempts:
        item = dict(a)
        if item["DiemSo"] is not None:
            item["DiemSo"] = float(item["DiemSo"])
        if item["ThoiGianBatDau"]:
            item["ThoiGianBatDau"] = item["ThoiGianBatDau"].isoformat()
        if item["ThoiGianNopBai"]:
            item["ThoiGianNopBai"] = item["ThoiGianNopBai"].isoformat()
        item["DaDat"] = bool(item["DaDat"]) if item["DaDat"] is not None else False
        item["DaNhanCup"] = bool(item["DaNhanCup"]) if item["DaNhanCup"] is not None else False

        if item["LoaiBoDe"] == "LUYEN_TAP":
            practice_count += 1
        else:
            exam_count += 1

        if item["TrangThai"] == "DA_NOP" and item["DiemSo"] is not None:
            completed_scores.append(item["DiemSo"])
            if item["DaDat"]:
                passed_count += 1

        attempt_list.append(item)

    cup_logs = db.execute(
        text("""
            SELECT
                MaBienDong,
                LoaiBienDong,
                MaThamChieu,
                SoCupThayDoi,
                SoCupTruoc,
                SoCupSau,
                MoTa,
                NgayTao
            FROM LichSuBienDongCup
            WHERE MaNguoiDung = :uid
            ORDER BY NgayTao DESC, MaBienDong DESC
        """),
        {"uid": user_id},
    ).mappings().all()

    cup_list = []
    for log in cup_logs:
        item = dict(log)
        if item["NgayTao"]:
            item["NgayTao"] = item["NgayTao"].isoformat()
        cup_list.append(item)

    current_cups = (
        user["SoCupHienTai"]
        if user["SoCupHienTai"] is not None
        else (cup_list[0]["SoCupSau"] if cup_list else 0)
    )
    avg_score = round(sum(completed_scores) / len(completed_scores), 2) if completed_scores else 0.0

    return {
        "user": {
            "MaNguoiDung": user["MaNguoiDung"],
            "HoTen": user["HoTen"],
            "Email": user["Email"],
            "SoCup": current_cups,
            "SoCupHienTai": current_cups,
            "MaHangHienTai": user["MaHangHienTai"] or 1,
            "TenHang": user["TenHang"] or "Đồng",
            "ThuTuHang": user["ThuTuHang"] or 1,
            "TrangThaiTaiKhoan": user["TrangThaiTaiKhoan"],
            "VaiTro": user["VaiTro"],
        },
        "summary": {
            "total_attempts": len(attempt_list),
            "practice_count": practice_count,
            "exam_count": exam_count,
            "completed_count": len(completed_scores),
            "passed_count": passed_count,
            "avg_score": avg_score,
        },
        "attempts": attempt_list,
        "cup_history": cup_list,
    }


@router.get("/attempts/{ma_luot_lam}")
def get_attempt_detail(ma_luot_lam: int, db: Session = Depends(get_db)):
    attempt = db.execute(
        text("""
            SELECT
                l.MaLuotLam,
                l.MaNguoiDung,
                u.HoTen,
                u.Email,
                l.MaBoDe,
                b.TieuDe AS TenBoDe,
                b.LoaiBoDe,
                c.TenChuDe,
                l.ThoiGianBatDau,
                l.ThoiGianNopBai,
                DATEDIFF(SECOND, l.ThoiGianBatDau, ISNULL(l.ThoiGianNopBai, GETDATE())) AS ThoiGianLamGiay,
                l.TrangThai,
                l.SoCauDung,
                l.TongSoCau,
                l.DiemSo,
                l.DaDat,
                l.DaNhanCup
            FROM LuotLamBai l
            INNER JOIN NguoiDung u ON l.MaNguoiDung = u.MaNguoiDung
            INNER JOIN BoDe b ON l.MaBoDe = b.MaBoDe
            LEFT JOIN ChuDe c ON b.MaChuDe = c.MaChuDe
            WHERE l.MaLuotLam = :lid
        """),
        {"lid": ma_luot_lam},
    ).mappings().first()

    if not attempt:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt làm bài.")

    questions = db.execute(
        text("""
            SELECT
                ct.ThuTuCau,
                ch.MaCauHoi,
                ch.NoiDung,
                ch.HinhAnhUrl,
                ch.MucDo,
                lc.TenLoai,
                lc.ChoPhepNhieuDapAn
            FROM ChiTietBoDe ct
            INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
            INNER JOIN LoaiCauHoi lc ON ch.MaLoaiCauHoi = lc.MaLoaiCauHoi
            WHERE ct.MaBoDe = :bode_id
            ORDER BY ct.ThuTuCau ASC
        """),
        {"bode_id": attempt["MaBoDe"]},
    ).mappings().all()

    all_answers = db.execute(
        text("""
            SELECT
                da.MaDapAn,
                da.MaCauHoi,
                da.NoiDung,
                da.LaDapAnDung,
                da.ThuTuHienThi
            FROM DapAn da
            INNER JOIN ChiTietBoDe ct ON da.MaCauHoi = ct.MaCauHoi
            WHERE ct.MaBoDe = :bode_id
            ORDER BY da.ThuTuHienThi ASC
        """),
        {"bode_id": attempt["MaBoDe"]},
    ).mappings().all()

    user_choices = db.execute(
        text("""
            SELECT MaCauHoi, MaDapAn
            FROM ChiTietTraLoiLuotLam
            WHERE MaLuotLam = :lid
        """),
        {"lid": ma_luot_lam},
    ).mappings().all()

    chosen_map = {}
    for row in user_choices:
        chosen_map.setdefault(row["MaCauHoi"], set()).add(row["MaDapAn"])

    answers_by_q = {}
    for ans in all_answers:
        answers_by_q.setdefault(ans["MaCauHoi"], []).append(dict(ans))

    question_details = []
    for q in questions:
        qid = q["MaCauHoi"]
        opts = answers_by_q.get(qid, [])
        selected_ids = chosen_map.get(qid, set())
        correct_ids = {o["MaDapAn"] for o in opts if o["LaDapAnDung"]}

        is_question_correct = len(correct_ids) > 0 and selected_ids == correct_ids

        formatted_opts = []
        for o in opts:
            formatted_opts.append({
                "MaDapAn": o["MaDapAn"],
                "NoiDung": o["NoiDung"],
                "LaDapAnDung": bool(o["LaDapAnDung"]),
                "NguoiDungChon": o["MaDapAn"] in selected_ids,
            })

        question_details.append({
            "ThuTuCau": q["ThuTuCau"],
            "MaCauHoi": qid,
            "NoiDung": q["NoiDung"],
            "HinhAnhUrl": q["HinhAnhUrl"],
            "MucDo": q["MucDo"],
            "TenLoai": q["TenLoai"],
            "ChoPhepNhieuDapAn": bool(q["ChoPhepNhieuDapAn"]),
            "DaTraLoi": len(selected_ids) > 0,
            "TraLoiDung": is_question_correct,
            "DapAn": formatted_opts,
        })

    attempt_info = dict(attempt)
    if attempt_info["DiemSo"] is not None:
        attempt_info["DiemSo"] = float(attempt_info["DiemSo"])
    if attempt_info["ThoiGianBatDau"]:
        attempt_info["ThoiGianBatDau"] = attempt_info["ThoiGianBatDau"].isoformat()
    if attempt_info["ThoiGianNopBai"]:
        attempt_info["ThoiGianNopBai"] = attempt_info["ThoiGianNopBai"].isoformat()
    attempt_info["DaDat"] = bool(attempt_info["DaDat"]) if attempt_info["DaDat"] is not None else False
    attempt_info["DaNhanCup"] = bool(attempt_info["DaNhanCup"]) if attempt_info["DaNhanCup"] is not None else False

    return {
        "attempt": attempt_info,
        "questions": question_details,
    }
DIFFICULTY_MAP_ADMIN = {
    1: "Rất dễ",
    2: "Dễ",
    3: "Trung bình",
    4: "Khó",
    5: "Siêu khó",
}


@router.get("/exams/{ma_bo_de}/feedbacks")
def get_exam_feedbacks_for_admin(ma_bo_de: int, db: Session = Depends(get_db)):
    """Admin xem toàn bộ đánh giá độ khó và góp ý báo lỗi/sự cố của thí sinh"""
    exam = db.execute(
        text("SELECT MaBoDe, TieuDe, LoaiBoDe FROM BoDe WHERE MaBoDe = :id"),
        {"id": ma_bo_de},
    ).mappings().first()

    if not exam:
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề.")

    rows = db.execute(
        text("""
            SELECT
                dg.MaDanhGia,
                dg.MaNguoiDung,
                u.HoTen,
                u.TenDangNhap,
                u.Email,
                u.AnhDaiDien,
                dg.SoSao,
                dg.BinhLuan AS GopY,
                dg.NgayDanhGia
            FROM DanhGiaBoDe dg
            INNER JOIN NguoiDung u ON dg.MaNguoiDung = u.MaNguoiDung
            WHERE dg.MaBoDe = :bo_de
            ORDER BY dg.NgayDanhGia DESC, dg.MaDanhGia DESC
        """),
        {"bo_de": ma_bo_de},
    ).mappings().all()

    total_reviews = len(rows)
    avg_stars = round(sum(r["SoSao"] for r in rows) / total_reviews, 1) if total_reviews > 0 else None

    return {
        "MaBoDe": exam["MaBoDe"],
        "TieuDe": exam["TieuDe"],
        "TongDanhGia": total_reviews,
        "DiemDoKhoTrungBinh": avg_stars,
        "items": [
            {
                "MaDanhGia": r["MaDanhGia"],
                "MaNguoiDung": r["MaNguoiDung"],
                "HoTen": r["HoTen"],
                "TenDangNhap": r["TenDangNhap"],
                "Email": r["Email"],
                "AnhDaiDien": r["AnhDaiDien"],
                "SoSao": r["SoSao"],
                "NhanMucDo": DIFFICULTY_MAP_ADMIN.get(r["SoSao"], "Trung bình"),
                "GopY": r["GopY"],
                "NgayDanhGia": r["NgayDanhGia"].isoformat() if r["NgayDanhGia"] else None,
            }
            for r in rows
        ],
    }
class AdminCreateTournamentRequest(BaseModel):
    MaChuDe: int
    SoCauHoi: int = Field(50, ge=5, le=100)
    MatKhauPhong: Optional[str] = Field(None, max_length=30)


class AdminCancelRoomRequest(BaseModel):
    LyDo: Optional[str] = Field("Quản trị viên đã hủy phòng đấu.", max_length=250)


@router.get("/arena/rooms")
def list_arena_rooms(
    loai_phong: Optional[str] = Query(None, pattern="^(DOI_KHANG_1VS1|GIAI_DAU_NN)$"),
    trang_thai: Optional[str] = Query(None, pattern="^(CHO_NGUOI_CHOI|DANG_DIEN_RA|DA_KET_THUC|DA_HUY)$"),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db),
):
    summary = db.execute(
        text("""
            SELECT
                COUNT(*) AS TongPhong,
                ISNULL(SUM(CASE WHEN LoaiPhong = 'DOI_KHANG_1VS1' THEN 1 ELSE 0 END), 0) AS Tong1vs1,
                ISNULL(SUM(CASE WHEN LoaiPhong = 'GIAI_DAU_NN' THEN 1 ELSE 0 END), 0) AS TongGiaiDau,
                ISNULL(SUM(CASE WHEN TrangThai IN ('CHO_NGUOI_CHOI', 'DANG_DIEN_RA') THEN 1 ELSE 0 END), 0) AS DangHoatDong
            FROM PhongThiDau
        """)
    ).mappings().first()

    conditions = ["1=1"]
    params = {}
    if loai_phong:
        conditions.append("p.LoaiPhong = :loai")
        params["loai"] = loai_phong
    if trang_thai:
        conditions.append("p.TrangThai = :st")
        params["st"] = trang_thai
    if search and search.strip():
        conditions.append("(p.MaCodePhong LIKE :kw OR u.HoTen LIKE :kw)")
        params["kw"] = f"%{search.strip()}%"

    where_clause = " AND ".join(conditions)
    total = db.execute(
        text(f"""
            SELECT COUNT(*)
            FROM PhongThiDau p
            LEFT JOIN NguoiDung u ON p.MaChuPhong = u.MaNguoiDung
            WHERE {where_clause}
        """),
        params,
    ).scalar()

    params["offset"] = (page - 1) * limit
    params["limit"] = limit

    rows = db.execute(
        text(f"""
            SELECT
                p.MaPhong,
                p.MaCodePhong,
                p.LoaiPhong,
                p.CheDoGhep,
                p.MaChuPhong,
                u.HoTen AS TenChuPhong,
                p.MatKhauPhong,
                p.TrangThai,
                p.ThoiGianBatDau,
                p.ThoiGianKetThuc,
                p.NgayTao,
                (SELECT COUNT(*) FROM ThanhVienPhongDau tv WHERE tv.MaPhong = p.MaPhong) AS SoNguoiThamGia
            FROM PhongThiDau p
            LEFT JOIN NguoiDung u ON p.MaChuPhong = u.MaNguoiDung
            WHERE {where_clause}
            ORDER BY p.NgayTao DESC, p.MaPhong DESC
            OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY
        """),
        params,
    ).mappings().all()

    items = []
    for r in rows:
        item = dict(r)
        rt_room = arena_manager.rooms.get(r["MaPhong"])
        item["TenChuDe"] = rt_room.ten_chu_de if rt_room else "Chủ đề đấu trường"
        item["CoMatKhau"] = bool(r["MatKhauPhong"])
        item["DangTrongRam"] = rt_room is not None
        if item["ThoiGianBatDau"]:
            item["ThoiGianBatDau"] = item["ThoiGianBatDau"].isoformat()
        if item["ThoiGianKetThuc"]:
            item["ThoiGianKetThuc"] = item["ThoiGianKetThuc"].isoformat()
        if item["NgayTao"]:
            item["NgayTao"] = item["NgayTao"].isoformat()
        items.append(item)

    return {
        "total": total,
        "summary": dict(summary) if summary else {},
        "items": items,
    }


@router.get("/arena/rooms/{ma_phong}")
def get_arena_room_detail(ma_phong: int, db: Session = Depends(get_db)):
    room = db.execute(
        text("""
            SELECT
                p.MaPhong, p.MaCodePhong, p.LoaiPhong, p.CheDoGhep,
                p.MaChuPhong, u.HoTen AS TenChuPhong,
                p.MatKhauPhong, p.TrangThai,
                p.ThoiGianBatDau, p.ThoiGianKetThuc, p.NgayTao
            FROM PhongThiDau p
            LEFT JOIN NguoiDung u ON p.MaChuPhong = u.MaNguoiDung
            WHERE p.MaPhong = :phong
        """),
        {"phong": ma_phong},
    ).mappings().first()

    if not room:
        raise HTTPException(status_code=404, detail="Không tìm thấy phòng thi đấu.")

    members = db.execute(
        text("""
            SELECT
                tv.MaThanhVienPhong,
                tv.MaNguoiDung,
                u.HoTen,
                u.Email,
                u.AnhDaiDien,
                tv.TrangThai,
                tv.SoCauDung,
                tv.TongThoiGianTraLoiMs,
                tv.ThuHang,
                tv.CupThayDoi
            FROM ThanhVienPhongDau tv
            INNER JOIN NguoiDung u ON tv.MaNguoiDung = u.MaNguoiDung
            WHERE tv.MaPhong = :phong
            ORDER BY
                CASE WHEN tv.ThuHang IS NULL THEN 999 ELSE tv.ThuHang END ASC,
                tv.SoCauDung DESC,
                tv.TongThoiGianTraLoiMs ASC
        """),
        {"phong": ma_phong},
    ).mappings().all()

    room_dict = dict(room)
    for k in ("ThoiGianBatDau", "ThoiGianKetThuc", "NgayTao"):
        if room_dict.get(k):
            room_dict[k] = room_dict[k].isoformat()

    return {
        "room": room_dict,
        "members": [dict(m) for m in members],
    }


@router.post("/arena/tournaments", status_code=status.HTTP_201_CREATED)
async def admin_create_tournament(
    payload: AdminCreateTournamentRequest,
    current_admin=Depends(require_admin),
):
    admin_id = int(current_admin["MaNguoiDung"]) if isinstance(current_admin, dict) else int(current_admin.MaNguoiDung)
    try:
        created = await arena_manager.admin_create_tournament_room(
            admin_id=admin_id,
            ma_chu_de=payload.MaChuDe,
            so_cau_hoi=payload.SoCauHoi,
            mat_khau_phong=payload.MatKhauPhong,
        )
        return {
            "message": f"Đã tạo phòng Giải đấu thành công! Mã phòng: {created['MaCodePhong']}",
            "room": created,
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Lỗi khi tạo phòng giải đấu: {str(e)}")


@router.post("/arena/rooms/{ma_phong}/cancel")
async def admin_cancel_arena_room(
    ma_phong: int,
    payload: AdminCancelRoomRequest,
):
    reason = (payload.LyDo or "").strip() or "Quản trị viên đã hủy phòng đấu."
    ok = await arena_manager.admin_force_cancel_room(ma_phong, reason)
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="Phòng không tồn tại hoặc đã kết thúc / bị hủy trước đó.",
        )
    return {"message": "Đã hủy phòng thi đấu và giải phóng thí sinh."}