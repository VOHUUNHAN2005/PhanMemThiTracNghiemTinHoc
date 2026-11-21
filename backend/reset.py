import random
from datetime import datetime, timedelta
from sqlalchemy import text
from app.database import SessionLocal


def seed_activity_for_users():
    db = SessionLocal()
    try:
        print("1. Đang làm sạch dữ liệu lịch sử cũ (ChiTietTraLoiLuotLam, LuotLamBai, LichSuBienDongCup)...")
        db.execute(text("DELETE FROM ChiTietTraLoiLuotLam"))
        db.execute(text("DELETE FROM LuotLamBai"))
        db.execute(text("DELETE FROM LichSuBienDongCup"))

        for table in ["LuotLamBai", "LichSuBienDongCup"]:
            try:
                db.execute(text(f"DBCC CHECKIDENT ('{table}', RESEED, 0)"))
            except Exception:
                pass

        students = db.execute(
            text("""
                SELECT MaNguoiDung, HoTen, Email, SoCupHienTai
                FROM NguoiDung
                WHERE VaiTro = 'THI_SINH'
                ORDER BY MaNguoiDung ASC
            """)
        ).mappings().all()

        if not students:
            print("Không tìm thấy tài khoản THI_SINH nào trong bảng NguoiDung!")
            return

        exams = db.execute(
            text("""
                SELECT
                    b.MaBoDe,
                    b.TieuDe,
                    b.LoaiBoDe,
                    b.DiemDatToiThieu,
                    COUNT(ct.MaCauHoi) AS SoCauHoi
                FROM BoDe b
                INNER JOIN ChiTietBoDe ct ON b.MaBoDe = ct.MaBoDe
                GROUP BY b.MaBoDe, b.TieuDe, b.LoaiBoDe, b.DiemDatToiThieu
                HAVING COUNT(ct.MaCauHoi) > 0
                ORDER BY b.MaBoDe ASC
            """)
        ).mappings().all()

        if not exams:
            print("Chưa có bộ đề nào chứa câu hỏi. Vui lòng sinh đề trước!")
            return

        # Kịch bản test cho từng thí sinh:
        # (index_bo_de, ty_le_lam_dung, trang_thai, cup_thuong, so_gio_truoc)
        scenarios_by_student = {
            0: [  # Thí Sinh Test 02 (MaNguoiDung = 1)
                (0, 0.85, "DA_NOP", 0, 72),    # Ôn tập Đề 01 -> Đạt (8.5đ)
                (1, 0.40, "DA_NOP", 0, 48),    # Ôn tập Đề 02 -> Chưa đạt (4.0đ)
                (5, 0.75, "DA_NOP", 50, 24),   # Đề thi chính thức 01 -> Đạt (7.5đ) +50 cúp
                (6, 0.55, "DA_NOP", 0, 5),     # Đề thi chính thức 02 -> Chưa đạt (5.5đ < 7.0đ)
                (2, 0.30, "DANG_LAM", 0, 1),   # Ôn tập Đề 03 -> Đang làm dở
            ],
            1: [  # Vo Huu Nhan (MaNguoiDung = 2)
                (0, 0.90, "DA_NOP", 0, 120),   # Ôn tập Đề 01 -> Đạt (9.0đ)
                (3, 0.80, "DA_NOP", 0, 96),    # Ôn tập Đề 04 -> Đạt (8.0đ)
                (5, 0.825, "DA_NOP", 50, 60),  # Đề thi chính thức 01 -> Đạt (8.25đ) +50 cúp
                (6, 0.90, "DA_NOP", 50, 36),   # Đề thi chính thức 02 -> Đạt (9.0đ) +50 cúp
                (7, 0.625, "DA_NOP", 0, 12),   # Đề thi chính thức 03 -> Chưa đạt (6.25đ < 7.0đ)
                (4, 1.00, "DA_NOP", 0, 3),     # Ôn tập Đề 05 -> Đạt tuyệt đối (10.0đ)
            ],
        }

        now = datetime.now()

        for s_idx, student in enumerate(students):
            uid = student["MaNguoiDung"]
            ho_ten = student["HoTen"]
            print(f"\n2. Đang tạo lịch sử hoạt động cho [{ho_ten}] (ID #{uid})...")

            running_cups = 0
            plan = scenarios_by_student.get(s_idx, [(5, 0.80, "DA_NOP", 50, 10)])
            plan_sorted = sorted(plan, key=lambda x: x[4], reverse=True)

            for exam_idx, correct_ratio, status, cup_reward, hours_ago in plan_sorted:
                exam = exams[exam_idx % len(exams)]
                ma_bo_de = exam["MaBoDe"]
                tong_cau = exam["SoCauHoi"]
                diem_dat_min = float(exam["DiemDatToiThieu"])

                q_rows = db.execute(
                    text("""
                        SELECT ct.ThuTuCau, ct.MaCauHoi
                        FROM ChiTietBoDe ct
                        WHERE ct.MaBoDe = :bid
                        ORDER BY ct.ThuTuCau ASC
                    """),
                    {"bid": ma_bo_de},
                ).mappings().all()

                target_correct = round(tong_cau * correct_ratio)
                all_q_ids = [r["MaCauHoi"] for r in q_rows]
                correct_q_set = set(random.sample(all_q_ids, min(target_correct, len(all_q_ids))))

                answered_q_ids = (
                    all_q_ids
                    if status == "DA_NOP"
                    else all_q_ids[: max(1, int(len(all_q_ids) * 0.6))]
                )

                start_time = now - timedelta(hours=hours_ago, minutes=18)
                submit_time = (now - timedelta(hours=hours_ago)) if status == "DA_NOP" else None

                actual_correct = 0
                chosen_records = []

                for qid in answered_q_ids:
                    opts = db.execute(
                        text("""
                            SELECT MaDapAn, LaDapAnDung
                            FROM DapAn
                            WHERE MaCauHoi = :qid
                            ORDER BY ThuTuHienThi ASC
                        """),
                        {"qid": qid},
                    ).mappings().all()

                    if not opts:
                        continue

                    right_opts = [o["MaDapAn"] for o in opts if o["LaDapAnDung"]]
                    wrong_opts = [o["MaDapAn"] for o in opts if not o["LaDapAnDung"]]

                    if qid in correct_q_set and right_opts:
                        picked_list = right_opts
                        actual_correct += 1
                    else:
                        picked_list = [random.choice(wrong_opts)] if wrong_opts else right_opts

                    for ans_id in picked_list:
                        chosen_records.append((qid, ans_id))

                score = round((actual_correct / tong_cau) * 10.0, 2) if status == "DA_NOP" else None
                is_passed = (score is not None and score >= diem_dat_min)
                earned_cup = (cup_reward > 0 and is_passed)

                ma_luot_lam = db.execute(
                    text("""
                        INSERT INTO LuotLamBai (
                            MaNguoiDung, MaBoDe, MaThietBiLamBai,
                            ThoiGianBatDau, ThoiGianNopBai, TrangThai,
                            SoCauDung, TongSoCau, DiemSo, DaDat, DaNhanCup
                        )
                        OUTPUT INSERTED.MaLuotLam
                        VALUES (
                            :uid, :bid, N'FLUTTER_MOBILE_TEST',
                            :start_t, :end_t, :status,
                            :dung, :tong, :diem, :dadat, :nhancup
                        )
                    """),
                    {
                        "uid": uid,
                        "bid": ma_bo_de,
                        "start_t": start_time,
                        "end_t": submit_time,
                        "status": status,
                        "dung": actual_correct,
                        "tong": tong_cau,
                        "diem": score,
                        "dadat": 1 if is_passed else 0,
                        "nhancup": 1 if earned_cup else 0,
                    },
                ).scalar()

                for idx_ans, (qid, ans_id) in enumerate(chosen_records):
                    db.execute(
                        text("""
                            INSERT INTO ChiTietTraLoiLuotLam (MaLuotLam, MaCauHoi, MaDapAn, ThoiGianChon)
                            VALUES (:lid, :qid, :aid, :t_chon)
                        """),
                        {
                            "lid": ma_luot_lam,
                            "qid": qid,
                            "aid": ans_id,
                            "t_chon": start_time + timedelta(seconds=15 * (idx_ans + 1)),
                        },
                    )

                # Chỉ ghi nhận thưởng cúp cho THI_CHINH_THUC_DAT theo đúng CHECK constraint
                if earned_cup:
                    cup_before = running_cups
                    running_cups += cup_reward
                    db.execute(
                        text("""
                            INSERT INTO LichSuBienDongCup (
                                MaNguoiDung, LoaiBienDong, MaThamChieu,
                                SoCupThayDoi, SoCupTruoc, SoCupSau, MoTa, NgayTao
                            )
                            VALUES (
                                :uid, 'THI_CHINH_THUC_DAT', :ref_id,
                                :delta, :before_c, :after_c, :mota, :ngay
                            )
                        """),
                        {
                            "uid": uid,
                            "ref_id": ma_luot_lam,
                            "delta": cup_reward,
                            "before_c": cup_before,
                            "after_c": running_cups,
                            "mota": f"Đạt kỳ thi chính thức '{exam['TieuDe']}' ({score}/10 điểm)",
                            "ngay": submit_time,
                        },
                    )

                print(
                    f"   -> Lượt #{ma_luot_lam}: {exam['TieuDe']} | {status} | "
                    f"Đúng {actual_correct}/{tong_cau} | Điểm: {score} | Đạt: {is_passed}"
                )

            # Thêm các biến động cúp đa dạng khớp đúng CHECK constraint của LichSuBienDongCup
            extra_cup_events = [
                ("THANG_1VS1", 25, "Thắng trận đấu đối kháng 1vs1", now - timedelta(hours=18)),
                ("THUA_1VS1", -15, "Thua trận đấu đối kháng 1vs1", now - timedelta(hours=10)),
                ("ADMIN_DIEU_CHINH", 150, "Admin thưởng chuyên cần tuần học tập tích cực", now - timedelta(hours=6)),
                ("PHAT_GIAN_LAN", -20, "Trừ cúp do thoát ứng dụng nhiều lần khi thi", now - timedelta(hours=2)),
            ]
            for loai_bd, delta, desc, log_time in extra_cup_events:
                before_c = running_cups
                # Đảm bảo SoCupSau >= 0 và SoCupSau == SoCupTruoc + SoCupThayDoi
                actual_delta = delta if (before_c + delta) >= 0 else -before_c
                running_cups = before_c + actual_delta

                db.execute(
                    text("""
                        INSERT INTO LichSuBienDongCup (
                            MaNguoiDung, LoaiBienDong, MaThamChieu,
                            SoCupThayDoi, SoCupTruoc, SoCupSau, MoTa, NgayTao
                        )
                        VALUES (
                            :uid, :loai, NULL,
                            :delta, :before_c, :after_c, :mota, :ngay
                        )
                    """),
                    {
                        "uid": uid,
                        "loai": loai_bd,
                        "delta": actual_delta,
                        "before_c": before_c,
                        "after_c": running_cups,
                        "mota": desc,
                        "ngay": log_time,
                    },
                )

            db.execute(
                text("UPDATE NguoiDung SET SoCupHienTai = :cups WHERE MaNguoiDung = :uid"),
                {"cups": running_cups, "uid": uid},
            )
            print(f"   => Tổng số cúp hiện tại của [{ho_ten}]: {running_cups} cúp.")

        db.commit()
        print("\nHOÀN TẤT! Đã nạp xong toàn bộ dữ liệu giả lịch sử hoạt động người dùng.")
    except Exception as e:
        db.rollback()
        print(f"LỖI KHI NẠP DỮ LIỆU GIẢ: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_activity_for_users()