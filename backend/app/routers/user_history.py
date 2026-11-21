from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from security import get_current_user

router = APIRouter(prefix="/api", tags=["User History & Notifications"])





@router.get("/users/me/history")
def get_my_activity_history(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]


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
                DATEDIFF(SECOND, l.ThoiGianBatDau, ISNULL(l.ThoiGianNopBai, SYSUTCDATETIME())) AS ThoiGianLamGiay,
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
        {"uid": me_id},
    ).mappings().all()

    attempt_list = []
    completed_scores = []
    passed_count = 0

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

        if item["TrangThai"] in ("DA_NOP", "HET_GIO") and item["DiemSo"] is not None:
            completed_scores.append(item["DiemSo"])
            if item["DaDat"]:
                passed_count += 1

        attempt_list.append(item)


    cup_logs = db.execute(
        text("""
            SELECT TOP 50
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
        {"uid": me_id},
    ).mappings().all()

    cup_list = []
    for log in cup_logs:
        item = dict(log)
        if item["NgayTao"]:
            item["NgayTao"] = item["NgayTao"].isoformat()
        cup_list.append(item)

    avg_score = round(sum(completed_scores) / len(completed_scores), 2) if completed_scores else 0.0

    return {
        "summary": {
            "total_attempts": len(attempt_list),
            "completed_count": len(completed_scores),
            "passed_count": passed_count,
            "avg_score": avg_score,
            "current_cups": current_user["SoCupHienTai"],
            "current_rank": current_user["TenHang"],
        },
        "attempts": attempt_list,
        "cup_history": cup_list,
    }


@router.get("/users/me/attempts/{ma_luot_lam}")
def get_my_attempt_detail(
    ma_luot_lam: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    attempt = db.execute(
        text("""
            SELECT
                l.MaLuotLam,
                l.MaNguoiDung,
                l.MaBoDe,
                b.TieuDe AS TenBoDe,
                b.LoaiBoDe,
                c.TenChuDe,
                l.ThoiGianBatDau,
                l.ThoiGianNopBai,
                DATEDIFF(SECOND, l.ThoiGianBatDau, ISNULL(l.ThoiGianNopBai, SYSUTCDATETIME())) AS ThoiGianLamGiay,
                l.TrangThai,
                l.SoCauDung,
                l.TongSoCau,
                l.DiemSo,
                l.DaDat,
                l.DaNhanCup
            FROM LuotLamBai l
            INNER JOIN BoDe b ON l.MaBoDe = b.MaBoDe
            LEFT JOIN ChuDe c ON b.MaChuDe = c.MaChuDe
            WHERE l.MaLuotLam = :lid
        """),
        {"lid": ma_luot_lam},
    ).mappings().first()

    if not attempt or attempt["MaNguoiDung"] != me_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy lượt làm bài.")


    if attempt["TrangThai"] not in ("DA_NOP", "HET_GIO"):
        raise HTTPException(
            status_code=403,
            detail="Chỉ có thể xem chi tiết đáp án đối với lượt làm bài đã hoàn thành.",
        )

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
            "DapAn": [
                {
                    "MaDapAn": o["MaDapAn"],
                    "NoiDung": o["NoiDung"],
                    "LaDapAnDung": bool(o["LaDapAnDung"]),
                    "NguoiDungChon": o["MaDapAn"] in selected_ids,
                }
                for o in opts
            ],
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





@router.get("/notifications")
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


@router.put("/notifications/read-all")
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
