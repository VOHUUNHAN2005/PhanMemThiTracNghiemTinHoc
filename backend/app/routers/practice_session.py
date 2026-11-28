from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.practice import CheckQuestionRequest
from security import get_current_user

router = APIRouter(prefix="/api/practice", tags=["Practice Session"])


def _build_practice_session_payload(db: Session, ma_luot_lam: int, ma_bo_de: int, tieu_de: str, diem_dat: float):
    """Lấy toàn bộ câu hỏi kèm tiến độ đã kiểm tra (ẩn LaDapAnDung với câu chưa làm)"""
    answered_rows = db.execute(
        text("""
            SELECT MaCauHoi, MaDapAn
            FROM ChiTietTraLoiLuotLam
            WHERE MaLuotLam = :ll_id
        """),
        {"ll_id": ma_luot_lam},
    ).mappings().all()

    user_answers_map: dict[int, list[int]] = {}
    for r in answered_rows:
        user_answers_map.setdefault(r["MaCauHoi"], []).append(r["MaDapAn"])

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
                da.LaDapAnDung,
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

    questions_dict: dict[int, dict] = {}
    for r in q_rows:
        q_id = r["MaCauHoi"]
        da_kiem_tra = q_id in user_answers_map

        if q_id not in questions_dict:
            questions_dict[q_id] = {
                "ThuTuCau": r["ThuTuCau"],
                "MaCauHoi": q_id,
                "NoiDung": r["NoiDungCauHoi"],
                "HinhAnhUrl": r["HinhAnhUrl"],
                "MucDo": r["MucDo"],
                "ChoPhepNhieuDapAn": bool(r["ChoPhepNhieuDapAn"]),
                "DaKiemTra": da_kiem_tra,
                "MaDapAnDaChon": user_answers_map.get(q_id, []),
                "LaCauDung": None,
                "DapAn": [],
            }

        questions_dict[q_id]["DapAn"].append({
            "MaDapAn": r["MaDapAn"],
            "NoiDung": r["NoiDungDapAn"],
            "ThuTuHienThi": r["ThuTuHienThi"],
            "LaDapAnDung": bool(r["LaDapAnDung"]) if da_kiem_tra else None,
            "_raw_is_correct": bool(r["LaDapAnDung"]),
        })

    questions_list = list(questions_dict.values())
    so_cau_da_lam = 0
    so_cau_dung = 0
    cau_tiep_theo_index = 0
    found_unanswered = False

    for idx, q in enumerate(questions_list):
        correct_ids = {d["MaDapAn"] for d in q["DapAn"] if d["_raw_is_correct"]}
        for d in q["DapAn"]:
            del d["_raw_is_correct"]

        if q["DaKiemTra"]:
            so_cau_da_lam += 1
            chosen_ids = set(q["MaDapAnDaChon"])
            is_q_correct = chosen_ids == correct_ids and len(correct_ids) > 0
            q["LaCauDung"] = is_q_correct
            if is_q_correct:
                so_cau_dung += 1
        elif not found_unanswered:
            cau_tiep_theo_index = idx
            found_unanswered = True

    if not found_unanswered and questions_list:
        cau_tiep_theo_index = len(questions_list) - 1

    return {
        "MaLuotLam": ma_luot_lam,
        "MaBoDe": ma_bo_de,
        "TieuDe": tieu_de,
        "DiemDatToiThieu": float(diem_dat),
        "TongSoCau": len(questions_list),
        "SoCauDaLam": so_cau_da_lam,
        "SoCauDung": so_cau_dung,
        "ViTriCauTiepTheo": cau_tiep_theo_index,
        "DanhSachCauHoi": questions_list,
    }


@router.post("/exams/{ma_bo_de}/start")
def start_or_resume_practice(
    ma_bo_de: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    bo_de = db.execute(
        text("""
            SELECT MaBoDe, TieuDe, LoaiBoDe, DiemDatToiThieu, TrangThai
            FROM BoDe
            WHERE MaBoDe = :id
        """),
        {"id": ma_bo_de},
    ).mappings().first()

    if not bo_de or bo_de["TrangThai"] != "CONG_KHAI":
        raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề hoặc bộ đề chưa công khai.")

    if bo_de["LoaiBoDe"] != "LUYEN_TAP":
        raise HTTPException(status_code=400, detail="Bộ đề này thuộc loại thi chính thức, không phải đề ôn tập.")

    existing_attempt = db.execute(
        text("""
            SELECT MaLuotLam
            FROM LuotLamBai
            WHERE MaNguoiDung = :me AND MaBoDe = :bo_de AND TrangThai = 'DANG_LAM'
        """),
        {"me": me_id, "bo_de": ma_bo_de},
    ).mappings().first()

    if existing_attempt:
        ma_luot_lam = existing_attempt["MaLuotLam"]
    else:
        tong_so_cau = db.execute(
            text("SELECT COUNT(*) FROM ChiTietBoDe WHERE MaBoDe = :bo_de"),
            {"bo_de": ma_bo_de},
        ).scalar() or 0

        if tong_so_cau == 0:
            raise HTTPException(status_code=400, detail="Bộ đề này chưa có câu hỏi nào.")

        ma_luot_lam = db.execute(
            text("""
                INSERT INTO LuotLamBai (MaNguoiDung, MaBoDe, MaThietBiLamBai, TrangThai, TongSoCau)
                OUTPUT INSERTED.MaLuotLam
                VALUES (:me, :bo_de, :device, 'DANG_LAM', :tong)
            """),
            {
                "me": me_id,
                "bo_de": ma_bo_de,
                "device": current_user.get("MaThietBiHienTai"),
                "tong": tong_so_cau,
            },
        ).scalar()
        db.commit()

    return _build_practice_session_payload(
        db=db,
        ma_luot_lam=ma_luot_lam,
        ma_bo_de=ma_bo_de,
        tieu_de=bo_de["TieuDe"],
        diem_dat=bo_de["DiemDatToiThieu"],
    )


@router.post("/attempts/{ma_luot_lam}/check-question")
def check_practice_question(
    ma_luot_lam: int,
    payload: CheckQuestionRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    attempt = db.execute(
        text("""
            SELECT llb.MaLuotLam, llb.MaNguoiDung, llb.MaBoDe, llb.TrangThai, bd.LoaiBoDe
            FROM LuotLamBai llb
            INNER JOIN BoDe bd ON llb.MaBoDe = bd.MaBoDe
            WHERE llb.MaLuotLam = :ll_id
        """),
        {"ll_id": ma_luot_lam},
    ).mappings().first()

    if not attempt or attempt["MaNguoiDung"] != me_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt làm bài.")

    if attempt["LoaiBoDe"] != "LUYEN_TAP":
        raise HTTPException(status_code=400, detail="API này chỉ dành cho lượt ôn tập.")

    if attempt["TrangThai"] != "DANG_LAM":
        raise HTTPException(status_code=400, detail="Lượt ôn tập này đã kết thúc.")

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
        raise HTTPException(status_code=400, detail="Câu hỏi không thuộc bộ đề đang làm.")

    unique_answer_ids = list(dict.fromkeys(payload.DanhSachMaDapAn))
    if not q_info["ChoPhepNhieuDapAn"] and len(unique_answer_ids) > 1:
        raise HTTPException(status_code=400, detail="Câu hỏi này chỉ được chọn 1 đáp án.")

    already_checked = db.execute(
        text("""
            SELECT TOP 1 1
            FROM ChiTietTraLoiLuotLam
            WHERE MaLuotLam = :ll_id AND MaCauHoi = :cau_hoi
        """),
        {"ll_id": ma_luot_lam, "cau_hoi": payload.MaCauHoi},
    ).first()

    if already_checked:
        raise HTTPException(status_code=409, detail="Câu hỏi này đã được kiểm tra đáp án trước đó.")

    try:
        for ans_id in unique_answer_ids:
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
        raise HTTPException(status_code=400, detail="Mã đáp án không hợp lệ hoặc không thuộc câu hỏi này.")

    ans_rows = db.execute(
        text("""
            SELECT MaDapAn, NoiDung, LaDapAnDung, ThuTuHienThi
            FROM DapAn
            WHERE MaCauHoi = :cau_hoi
            ORDER BY ThuTuHienThi ASC
        """),
        {"cau_hoi": payload.MaCauHoi},
    ).mappings().all()

    correct_ids = {r["MaDapAn"] for r in ans_rows if r["LaDapAnDung"]}
    is_correct = set(unique_answer_ids) == correct_ids

    return {
        "MaCauHoi": payload.MaCauHoi,
        "LaCauDung": is_correct,
        "MaDapAnDaChon": unique_answer_ids,
        "DanhSachMaDapAnDung": list(correct_ids),
        "DapAn": [
            {
                "MaDapAn": r["MaDapAn"],
                "NoiDung": r["NoiDung"],
                "ThuTuHienThi": r["ThuTuHienThi"],
                "LaDapAnDung": bool(r["LaDapAnDung"]),
            }
            for r in ans_rows
        ],
    }


@router.post("/attempts/{ma_luot_lam}/finish")
def finish_practice_attempt(
    ma_luot_lam: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    attempt = db.execute(
        text("""
            SELECT llb.MaLuotLam, llb.MaNguoiDung, llb.MaBoDe, llb.TrangThai, llb.TongSoCau,
                   bd.LoaiBoDe, bd.DiemDatToiThieu
            FROM LuotLamBai llb
            INNER JOIN BoDe bd ON llb.MaBoDe = bd.MaBoDe
            WHERE llb.MaLuotLam = :ll_id
        """),
        {"ll_id": ma_luot_lam},
    ).mappings().first()

    if not attempt or attempt["MaNguoiDung"] != me_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt làm bài.")

    if attempt["LoaiBoDe"] != "LUYEN_TAP":
        raise HTTPException(status_code=400, detail="API này chỉ dành cho lượt ôn tập.")

    if attempt["TrangThai"] != "DANG_LAM":
        raise HTTPException(status_code=400, detail="Lượt ôn tập này đã được nộp trước đó.")

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
        {"bo_de": attempt["MaBoDe"]},
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

    db.execute(
        text("""
            UPDATE LuotLamBai
            SET TrangThai = 'DA_NOP',
                ThoiGianNopBai = DATEADD(HOUR, 7, SYSUTCDATETIME()),
                SoCauDung = :dung,
                DiemSo = :diem,
                DaDat = :dat
            WHERE MaLuotLam = :ll_id
        """),
        {
            "dung": so_cau_dung,
            "diem": diem_so,
            "dat": da_dat,
            "ll_id": ma_luot_lam,
        },
    )
    db.commit()

    return {
        "message": "Hoàn thành bài ôn tập!",
        "MaLuotLam": ma_luot_lam,
        "SoCauDung": so_cau_dung,
        "TongSoCau": tong_so_cau,
        "DiemSo": diem_so,
        "DaDat": bool(da_dat),
    }


@router.delete("/attempts/{ma_luot_lam}")
def cancel_practice_attempt(
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
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt làm bài.")

    if attempt["LoaiBoDe"] != "LUYEN_TAP":
        raise HTTPException(status_code=400, detail="Không thể hủy lượt thi chính thức bằng API này.")

    if attempt["TrangThai"] != "DANG_LAM":
        raise HTTPException(status_code=400, detail="Chỉ có thể hủy lượt ôn tập đang làm dở.")

    db.execute(text("DELETE FROM ChiTietTraLoiLuotLam WHERE MaLuotLam = :ll_id"), {"ll_id": ma_luot_lam})
    db.execute(text("DELETE FROM LuotLamBai WHERE MaLuotLam = :ll_id"), {"ll_id": ma_luot_lam})
    db.commit()

    return {"message": "Đã hủy lượt ôn tập đang làm dở."}