from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.official_exam import SaveExamAnswerRequest
from security import get_current_user

router = APIRouter(prefix="/api/official", tags=["Official Exam"])

CUP_THUONG_THI_DAT = 100
NETWORK_GRACE_SECONDS = 5


class CheatReportRequest(BaseModel):
    LyDo: str = Field("Gian lận trong phòng thi", max_length=30)


def _parse_utc(dt_val) -> datetime:
    if isinstance(dt_val, str):
        dt_val = datetime.fromisoformat(dt_val.replace("Z", "+00:00"))
    if dt_val.tzinfo is None:
        return dt_val.replace(tzinfo=timezone.utc)
    return dt_val.astimezone(timezone.utc)


def _grade_and_finalize_attempt(db: Session, attempt: dict, force_status: str | None = None) -> dict:
    ma_luot_lam = attempt["MaLuotLam"]
    me_id = attempt["MaNguoiDung"]
    ma_bo_de = attempt["MaBoDe"]

    now_utc = datetime.now(timezone.utc)
    start_utc = _parse_utc(attempt["ThoiGianBatDau"])
    limit_minutes = attempt["ThoiGianLamBai"] or 0
    deadline_utc = start_utc + timedelta(minutes=limit_minutes, seconds=NETWORK_GRACE_SECONDS)

    if force_status:
        final_status = force_status
    elif limit_minutes > 0 and now_utc > deadline_utc:
        final_status = "HET_GIO"
    else:
        final_status = "DA_NOP"

    user_rows = db.execute(
        text("SELECT MaCauHoi, MaDapAn FROM ChiTietTraLoiLuotLam WHERE MaLuotLam = :ll_id"),
        {"ll_id": ma_luot_lam},
    ).mappings().all()

    user_map: dict[int, set[int]] = {}
    for r in user_rows:
        user_map.setdefault(r["MaCauHoi"], set()).add(r["MaDapAn"])

    correct_rows = db.execute(
        text("""
            SELECT ct.MaCauHoi, da.MaDapAn
            FROM ChiTietBoDe ct
            INNER JOIN DapAn da ON ct.MaCauHoi = da.MaCauHoi
            WHERE ct.MaBoDe = :bo_de AND da.LaDapAnDung = 1
        """),
        {"bo_de": ma_bo_de},
    ).mappings().all()

    correct_map: dict[int, set[int]] = {}
    for r in correct_rows:
        correct_map.setdefault(r["MaCauHoi"], set()).add(r["MaDapAn"])

    so_cau_dung = sum(
        1 for q_id, c_ans in correct_map.items()
        if user_map.get(q_id, set()) == c_ans and len(c_ans) > 0
    )

    tong_so_cau = attempt["TongSoCau"] or len(correct_map)
    diem_so = round((so_cau_dung / tong_so_cau) * 10, 2) if tong_so_cau > 0 else 0.0
    da_dat = 1 if diem_so >= float(attempt["DiemDatToiThieu"]) else 0

    cup_nhan_duoc = 0
    if da_dat == 1:
        already_rewarded = db.execute(
            text("""
                SELECT TOP 1 1
                FROM LuotLamBai
                WHERE MaNguoiDung = :me AND MaBoDe = :bo_de AND DaNhanCup = 1
            """),
            {"me": me_id, "bo_de": ma_bo_de},
        ).first()

        if not already_rewarded:
            cup_nhan_duoc = CUP_THUONG_THI_DAT
            cup_truoc = db.execute(
                text("SELECT ISNULL(SoCupHienTai, 0) FROM NguoiDung WHERE MaNguoiDung = :me"),
                {"me": me_id},
            ).scalar() or 0
            cup_sau = cup_truoc + cup_nhan_duoc

            new_rank_id = db.execute(
                text("""
                    SELECT TOP 1 MaHang
                    FROM CapBacHang
                    WHERE CupToiThieu <= :cup_sau
                    ORDER BY CupToiThieu DESC, ThuTuHang DESC
                """),
                {"cup_sau": cup_sau},
            ).scalar()

            db.execute(
                text("""
                    UPDATE NguoiDung
                    SET SoCupHienTai = :cup_sau,
                        MaHangHienTai = COALESCE(:ma_hang, MaHangHienTai)
                    WHERE MaNguoiDung = :me
                """),
                {"cup_sau": cup_sau, "ma_hang": new_rank_id, "me": me_id},
            )
            db.execute(
                text("""
                    INSERT INTO LichSuBienDongCup (
                        MaNguoiDung, LoaiBienDong, MaThamChieu,
                        SoCupThayDoi, SoCupTruoc, SoCupSau, MoTa, NgayTao
                    )
                    VALUES (
                        :me, 'THI_CHINH_THUC_DAT', :ll_id,
                        :cup, :truoc, :sau, :mota, SYSUTCDATETIME()
                    )
                """),
                {
                    "me": me_id,
                    "ll_id": ma_luot_lam,
                    "cup": cup_nhan_duoc,
                    "truoc": cup_truoc,
                    "sau": cup_sau,
                    "mota": f"Đạt bài thi chính thức (Mã bộ đề #{ma_bo_de})",
                },
            )

    db.execute(
        text("""
            UPDATE LuotLamBai
            SET TrangThai = :status,
                ThoiGianNopBai = SYSUTCDATETIME(),
                SoCauDung = :dung,
                DiemSo = :diem,
                DaDat = :dat,
                DaNhanCup = :nhan_cup
            WHERE MaLuotLam = :ll_id
        """),
        {
            "status": final_status,
            "dung": so_cau_dung,
            "diem": diem_so,
            "dat": da_dat,
            "nhan_cup": 1 if cup_nhan_duoc > 0 else 0,
            "ll_id": ma_luot_lam,
        },
    )
    db.commit()

    return {
        "MaLuotLam": ma_luot_lam,
        "TrangThai": final_status,
        "SoCauDung": so_cau_dung,
        "TongSoCau": tong_so_cau,
        "DiemSo": diem_so,
        "DiemDatToiThieu": float(attempt["DiemDatToiThieu"]),
        "DaDat": bool(da_dat),
        "CupNhanDuoc": cup_nhan_duoc,
        "ThongBao": (
            f"Chúc mừng bạn đã ĐẠT bài thi chính thức (+{cup_nhan_duoc} cúp)!"
            if da_dat == 1 and cup_nhan_duoc > 0
            else (
                "Chúc mừng bạn đã ĐẠT bài thi chính thức!"
                if da_dat == 1
                else ("Đã hết thời gian làm bài và hệ thống tự động nộp bài." if final_status == "HET_GIO" else "Bạn chưa đạt điểm tối thiểu. Hãy ôn tập thêm và thử lại!")
            )
        ),
    }


@router.post("/exams/{ma_bo_de}/start")
def start_official_exam(
    ma_bo_de: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    bo_de = db.execute(
        text("""
            SELECT MaBoDe, TieuDe, LoaiBoDe, ThoiGianLamBai, DiemDatToiThieu, TrangThai
            FROM BoDe
            WHERE MaBoDe = :id
        """),
        {"id": ma_bo_de},
    ).mappings().first()

    if not bo_de or bo_de["TrangThai"] != "CONG_KHAI":
        raise HTTPException(status_code=404, detail="Không tìm thấy đề thi hoặc đề thi chưa công khai.")

    if bo_de["LoaiBoDe"] != "THI_CHINH_THUC":
        raise HTTPException(status_code=400, detail="Bộ đề này là đề ôn tập, không phải đề thi chính thức.")

    if not bo_de["ThoiGianLamBai"] or bo_de["ThoiGianLamBai"] <= 0:
        raise HTTPException(status_code=400, detail="Đề thi chính thức chưa được cấu hình thời gian làm bài.")

    passed_before = db.execute(
        text("""
            SELECT TOP 1 1
            FROM LuotLamBai
            WHERE MaNguoiDung = :me AND MaBoDe = :bo_de AND DaDat = 1
        """),
        {"me": me_id, "bo_de": ma_bo_de},
    ).first()

    if passed_before:
        raise HTTPException(
            status_code=403,
            detail="Bạn đã vượt qua đề thi chính thức này rồi, không thể thi lại nữa.",
        )

    stale_attempts = db.execute(
        text("""
            SELECT MaLuotLam
            FROM LuotLamBai
            WHERE MaNguoiDung = :me AND MaBoDe = :bo_de AND TrangThai = 'DANG_LAM'
        """),
        {"me": me_id, "bo_de": ma_bo_de},
    ).mappings().all()

    if stale_attempts:
        for old in stale_attempts:
            db.execute(
                text("""
                    UPDATE LuotLamBai
                    SET TrangThai = 'HUY_GIAN_LAN',
                        ThoiGianNopBai = SYSUTCDATETIME(),
                        SoCauDung = 0,
                        DiemSo = 0,
                        DaDat = 0
                    WHERE MaLuotLam = :ll_id
                """),
                {"ll_id": old["MaLuotLam"]},
            )
        db.commit()

    q_rows = db.execute(
        text("""
            SELECT
                ct.ThuTuCau,
                ch.MaCauHoi,
                ch.NoiDung AS NoiDungCauHoi,
                ch.HinhAnhUrl,
                ch.MucDo,
                lch.ChoPhepNhieuDapAn,
                da.MaDapAn,
                da.NoiDung AS NoiDungDapAn,
                da.ThuTuHienThi
            FROM ChiTietBoDe ct
            INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
            INNER JOIN LoaiCauHoi lch ON ch.MaLoaiCauHoi = lch.MaLoaiCauHoi
            INNER JOIN DapAn da ON ch.MaCauHoi = da.MaCauHoi
            WHERE ct.MaBoDe = :bo_de_id
            ORDER BY ct.ThuTuCau ASC, da.ThuTuHienThi ASC
        """),
        {"bo_de_id": ma_bo_de},
    ).mappings().all()

    if not q_rows:
        raise HTTPException(status_code=400, detail="Đề thi này chưa có câu hỏi nào.")

    questions_dict: dict[int, dict] = {}
    for r in q_rows:
        q_id = r["MaCauHoi"]
        if q_id not in questions_dict:
            questions_dict[q_id] = {
                "ThuTuCau": r["ThuTuCau"],
                "MaCauHoi": q_id,
                "NoiDung": r["NoiDungCauHoi"],
                "HinhAnhUrl": r["HinhAnhUrl"],
                "MucDo": r["MucDo"],
                "ChoPhepNhieuDapAn": bool(r["ChoPhepNhieuDapAn"]),
                "DapAn": [],
            }
        questions_dict[q_id]["DapAn"].append({
            "MaDapAn": r["MaDapAn"],
            "NoiDung": r["NoiDungDapAn"],
            "ThuTuHienThi": r["ThuTuHienThi"],
        })

    questions_list = list(questions_dict.values())
    tong_so_cau = len(questions_list)

    inserted = db.execute(
        text("""
            INSERT INTO LuotLamBai (MaNguoiDung, MaBoDe, MaThietBiLamBai, TrangThai, TongSoCau)
            OUTPUT INSERTED.MaLuotLam, INSERTED.ThoiGianBatDau
            VALUES (:me, :bo_de, :device, 'DANG_LAM', :tong)
        """),
        {
            "me": me_id,
            "bo_de": ma_bo_de,
            "device": current_user.get("MaThietBiHienTai"),
            "tong": tong_so_cau,
        },
    ).mappings().first()
    db.commit()

    start_utc = _parse_utc(inserted["ThoiGianBatDau"])
    thoi_gian_giay = bo_de["ThoiGianLamBai"] * 60
    het_han_utc = start_utc + timedelta(seconds=thoi_gian_giay)

    return {
        "MaLuotLam": inserted["MaLuotLam"],
        "MaBoDe": ma_bo_de,
        "TieuDe": bo_de["TieuDe"],
        "ThoiGianLamBaiPhut": bo_de["ThoiGianLamBai"],
        "ThoiGianConLaiGiay": thoi_gian_giay,
        "ThoiGianHetHanUTC": het_han_utc.isoformat(),
        "DiemDatToiThieu": float(bo_de["DiemDatToiThieu"]),
        "TongSoCau": tong_so_cau,
        "DanhSachCauHoi": questions_list,
    }


@router.post("/attempts/{ma_luot_lam}/answer")
def save_official_answer(
    ma_luot_lam: int,
    payload: SaveExamAnswerRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    attempt = db.execute(
        text("""
            SELECT llb.MaLuotLam, llb.MaNguoiDung, llb.MaBoDe, llb.TrangThai, llb.ThoiGianBatDau,
                   bd.LoaiBoDe, bd.ThoiGianLamBai
            FROM LuotLamBai llb
            INNER JOIN BoDe bd ON llb.MaBoDe = bd.MaBoDe
            WHERE llb.MaLuotLam = :ll_id
        """),
        {"ll_id": ma_luot_lam},
    ).mappings().first()

    if not attempt or attempt["MaNguoiDung"] != me_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt thi.")

    if attempt["LoaiBoDe"] != "THI_CHINH_THUC":
        raise HTTPException(status_code=400, detail="API này chỉ dành cho đề thi chính thức.")

    if attempt["TrangThai"] != "DANG_LAM":
        raise HTTPException(status_code=400, detail="Lượt thi đã kết thúc hoặc bị hủy.")

    start_utc = _parse_utc(attempt["ThoiGianBatDau"])
    deadline_utc = start_utc + timedelta(minutes=attempt["ThoiGianLamBai"], seconds=NETWORK_GRACE_SECONDS)
    if datetime.now(timezone.utc) > deadline_utc:
        raise HTTPException(status_code=408, detail="Đã hết thời gian làm bài!")

    q_info = db.execute(
        text("""
            SELECT ch.MaCauHoi, lch.ChoPhepNhieuDapAn
            FROM ChiTietBoDe ct
            INNER JOIN CauHoi ch ON ct.MaCauHoi = ch.MaCauHoi
            INNER JOIN LoaiCauHoi lch ON ch.MaLoaiCauHoi = lch.MaLoaiCauHoi
            WHERE ct.MaBoDe = :bo_de AND ct.MaCauHoi = :cau_hoi
        """),
        {"bo_de": attempt["MaBoDe"], "cau_hoi": payload.MaCauHoi},
    ).mappings().first()

    if not q_info:
        raise HTTPException(status_code=400, detail="Câu hỏi không thuộc đề thi này.")

    unique_ans = list(dict.fromkeys(payload.DanhSachMaDapAn))
    if not q_info["ChoPhepNhieuDapAn"] and len(unique_ans) > 1:
        raise HTTPException(status_code=400, detail="Câu hỏi này chỉ được chọn 1 đáp án.")

    try:
        db.execute(
            text("DELETE FROM ChiTietTraLoiLuotLam WHERE MaLuotLam = :ll_id AND MaCauHoi = :cau_hoi"),
            {"ll_id": ma_luot_lam, "cau_hoi": payload.MaCauHoi},
        )
        for ans_id in unique_ans:
            db.execute(
                text("""
                    INSERT INTO ChiTietTraLoiLuotLam (MaLuotLam, MaCauHoi, MaDapAn)
                    VALUES (:ll_id, :cau_hoi, :dap_an)
                """),
                {"ll_id": ma_luot_lam, "cau_hoi": payload.MaCauHoi, "dap_an": ans_id},
            )
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail="Mã đáp án không hợp lệ.")

    return {"saved": True, "MaCauHoi": payload.MaCauHoi, "MaDapAnDaChon": unique_ans}


@router.post("/attempts/{ma_luot_lam}/submit")
def submit_official_exam(
    ma_luot_lam: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    attempt = db.execute(
        text("""
            SELECT llb.MaLuotLam, llb.MaNguoiDung, llb.MaBoDe, llb.TrangThai,
                   llb.ThoiGianBatDau, llb.TongSoCau,
                   bd.LoaiBoDe, bd.ThoiGianLamBai, bd.DiemDatToiThieu
            FROM LuotLamBai llb
            INNER JOIN BoDe bd ON llb.MaBoDe = bd.MaBoDe
            WHERE llb.MaLuotLam = :ll_id
        """),
        {"ll_id": ma_luot_lam},
    ).mappings().first()

    if not attempt or attempt["MaNguoiDung"] != me_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt thi.")

    if attempt["LoaiBoDe"] != "THI_CHINH_THUC":
        raise HTTPException(status_code=400, detail="API này chỉ dành cho đề thi chính thức.")

    if attempt["TrangThai"] != "DANG_LAM":
        raise HTTPException(status_code=400, detail="Lượt thi này đã được nộp hoặc đã bị hủy trước đó.")

    return _grade_and_finalize_attempt(db=db, attempt=dict(attempt))


@router.post("/attempts/{ma_luot_lam}/abort")
def abort_official_exam(
    ma_luot_lam: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    attempt = db.execute(
        text("""
            SELECT llb.MaLuotLam, llb.MaNguoiDung, llb.TrangThai, bd.LoaiBoDe
            FROM LuotLamBai llb
            INNER JOIN BoDe bd ON llb.MaBoDe = bd.MaBoDe
            WHERE llb.MaLuotLam = :ll_id
        """),
        {"ll_id": ma_luot_lam},
    ).mappings().first()

    if not attempt or attempt["MaNguoiDung"] != me_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt thi.")

    if attempt["TrangThai"] == "DANG_LAM":
        db.execute(
            text("""
                UPDATE LuotLamBai
                SET TrangThai = 'HUY_GIAN_LAN',
                    ThoiGianNopBai = SYSUTCDATETIME(),
                    SoCauDung = 0,
                    DiemSo = 0,
                    DaDat = 0
                WHERE MaLuotLam = :ll_id
            """),
            {"ll_id": ma_luot_lam},
        )
        db.commit()

    return {"message": "Lượt thi đã bị hủy do rời khỏi phòng thi.", "TrangThai": "HUY_GIAN_LAN"}


@router.post("/attempts/{ma_luot_lam}/cheat")
def report_official_exam_cheat(
    ma_luot_lam: int,
    payload: CheatReportRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Phát hiện gian lận khi thi chính thức -> Hủy bài & Khóa vĩnh viễn tài khoản"""
    me_id = current_user["MaNguoiDung"]
    ly_do = (payload.LyDo or "Gian lận trong phòng thi").strip()[:30]

    db.execute(
        text("""
            UPDATE LuotLamBai
            SET TrangThai = 'HUY_GIAN_LAN',
                ThoiGianNopBai = SYSUTCDATETIME(),
                SoCauDung = 0,
                DiemSo = 0,
                DaDat = 0
            WHERE MaLuotLam = :ll_id AND MaNguoiDung = :me AND TrangThai = 'DANG_LAM'
        """),
        {"ll_id": ma_luot_lam, "me": me_id},
    )

    db.execute(
        text("""
            UPDATE NguoiDung
            SET TrangThaiTaiKhoan = 'BI_KHOA',
                LyDoKhoa = :ly_do,
                TrangThaiOnline = 0
            WHERE MaNguoiDung = :me
        """),
        {"ly_do": ly_do, "me": me_id},
    )
    db.commit()

    return {
        "message": "Phát hiện hành vi gian lận. Bài thi đã bị hủy và tài khoản của bạn đã bị khóa.",
        "TrangThaiTaiKhoan": "BI_KHOA",
    }
