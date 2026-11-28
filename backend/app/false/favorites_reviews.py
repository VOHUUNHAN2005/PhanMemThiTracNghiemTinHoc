# from typing import Optional
# from fastapi import APIRouter, Depends, HTTPException, status
# from pydantic import BaseModel, Field
# from sqlalchemy import text
# from sqlalchemy.orm import Session

# from app.database import get_db
# from security import get_current_user

# router = APIRouter(prefix="/api", tags=["Favorites & Exam Difficulty Reviews"])

# DIFFICULTY_LABELS = {
#     1: "Rất dễ",
#     2: "Dễ",
#     3: "Trung bình",
#     4: "Khó",
#     5: "Siêu khó",
# }


# def _get_difficulty_label(avg_score: float | None) -> str | None:
#     if avg_score is None or avg_score <= 0:
#         return None
#     rounded = max(1, min(5, round(avg_score)))
#     return DIFFICULTY_LABELS.get(rounded, "Trung bình")


# class ExamDifficultyReviewRequest(BaseModel):
#     SoSao: int = Field(..., ge=1, le=5, description="1: Rất dễ, 2: Dễ, 3: Trung bình, 4: Khó, 5: Siêu khó")
#     BinhLuan: Optional[str] = Field(None, max_length=1000, description="Góp ý báo lỗi/sự cố gửi riêng cho Admin")


# # ==========================================
# # 1. PHÂN HỆ YÊU THÍCH BỘ ĐỀ (NHÓM THEO CHỦ ĐỀ)
# # ==========================================

# @router.post("/favorites/exams/{ma_bo_de}/toggle")
# def toggle_favorite_exam(
#     ma_bo_de: int,
#     current_user: dict = Depends(get_current_user),
#     db: Session = Depends(get_db),
# ):
#     me_id = current_user["MaNguoiDung"]

#     bo_de = db.execute(
#         text("SELECT MaBoDe, TieuDe FROM BoDe WHERE MaBoDe = :id AND TrangThai = 'CONG_KHAI'"),
#         {"id": ma_bo_de},
#     ).mappings().first()

#     if not bo_de:
#         raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề hoặc bộ đề chưa công khai.")

#     existing = db.execute(
#         text("""
#             SELECT 1 FROM BoDeYeuThich
#             WHERE MaNguoiDung = :me AND MaBoDe = :bo_de
#         """),
#         {"me": me_id, "bo_de": ma_bo_de},
#     ).first()

#     if existing:
#         db.execute(
#             text("DELETE FROM BoDeYeuThich WHERE MaNguoiDung = :me AND MaBoDe = :bo_de"),
#             {"me": me_id, "bo_de": ma_bo_de},
#         )
#         db.commit()
#         return {
#             "MaBoDe": ma_bo_de,
#             "is_favorite": False,
#             "message": "Đã bỏ khỏi danh sách bộ đề yêu thích.",
#         }

#     db.execute(
#         text("""
#             INSERT INTO BoDeYeuThich (MaNguoiDung, MaBoDe, NgayLuu)
#             VALUES (:me, :bo_de, GETDATE())
#         """),
#         {"me": me_id, "bo_de": ma_bo_de},
#     )
#     db.commit()
#     return {
#         "MaBoDe": ma_bo_de,
#         "is_favorite": True,
#         "message": "Đã thêm vào danh sách bộ đề yêu thích!",
#     }


# @router.get("/favorites/me")
# def get_my_favorite_exams_grouped_by_topic(
#     current_user: dict = Depends(get_current_user),
#     db: Session = Depends(get_db),
# ):
#     """Lấy danh sách bộ đề yêu thích của user và tự động gom nhóm theo Chủ đề"""
#     me_id = current_user["MaNguoiDung"]

#     rows = db.execute(
#         text("""
#             SELECT
#                 yt.MaBoDe,
#                 yt.NgayLuu,
#                 bd.TieuDe,
#                 bd.MoTa,
#                 bd.LoaiBoDe,
#                 bd.ThoiGianLamBai,
#                 bd.DiemDatToiThieu,
#                 ISNULL(cd.MaChuDe, 0) AS MaChuDe,
#                 ISNULL(cd.TenChuDe, N'Chủ đề chung') AS TenChuDe,
#                 cd.MoTa AS MoTaChuDe,
#                 (SELECT COUNT(*) FROM ChiTietBoDe ct WHERE ct.MaBoDe = bd.MaBoDe) AS SoLuongCauHoi,
#                 CAST(
#                     CASE WHEN EXISTS (
#                         SELECT 1 FROM LuotLamBai llb
#                         WHERE llb.MaBoDe = bd.MaBoDe
#                           AND llb.MaNguoiDung = :me
#                           AND llb.DaDat = 1
#                     ) THEN 1 ELSE 0 END AS BIT
#                 ) AS DaDat
#             FROM BoDeYeuThich yt
#             INNER JOIN BoDe bd ON yt.MaBoDe = bd.MaBoDe
#             LEFT JOIN ChuDe cd ON bd.MaChuDe = cd.MaChuDe
#             WHERE yt.MaNguoiDung = :me
#               AND bd.TrangThai = 'CONG_KHAI'
#             ORDER BY cd.TenChuDe ASC, yt.NgayLuu DESC
#         """),
#         {"me": me_id},
#     ).mappings().all()

#     favorite_ids = [r["MaBoDe"] for r in rows]
#     topics_map: dict[int, dict] = {}

#     for r in rows:
#         cd_id = r["MaChuDe"]
#         if cd_id not in topics_map:
#             topics_map[cd_id] = {
#                 "MaChuDe": cd_id,
#                 "TenChuDe": r["TenChuDe"],
#                 "MoTa": r["MoTaChuDe"],
#                 "SoBoDeYeuThich": 0,
#                 "DanhSachBoDe": [],
#             }

#         topics_map[cd_id]["SoBoDeYeuThich"] += 1
#         topics_map[cd_id]["DanhSachBoDe"].append({
#             "MaBoDe": r["MaBoDe"],
#             "TieuDe": r["TieuDe"],
#             "MoTa": r["MoTa"],
#             "LoaiBoDe": r["LoaiBoDe"],
#             "ThoiGianLamBai": r["ThoiGianLamBai"],
#             "DiemDatToiThieu": float(r["DiemDatToiThieu"]),
#             "SoLuongCauHoi": r["SoLuongCauHoi"] or 0,
#             "DaDat": bool(r["DaDat"]),
#             "NgayLuu": r["NgayLuu"].isoformat() if r["NgayLuu"] else None,
#         })

#     return {
#         "total_favorites": len(favorite_ids),
#         "favorite_exam_ids": favorite_ids,
#         "topics": list(topics_map.values()),
#     }


# # ==========================================
# # 2. PHÂN HỆ ĐÁNH GIÁ ĐỘ KHÓ & GÓP Ý ĐỀ THI CHÍNH THỨC
# # ==========================================

# @router.get("/official/exams/{ma_bo_de}/review-summary")
# def get_official_exam_review_summary(
#     ma_bo_de: int,
#     current_user: dict = Depends(get_current_user),
#     db: Session = Depends(get_db),
# ):
#     """Lấy thống kê độ khó trung bình của đề thi chính thức + đánh giá của chính user (ẩn góp ý người khác)"""
#     me_id = current_user["MaNguoiDung"]

#     bo_de = db.execute(
#         text("SELECT MaBoDe, TieuDe, LoaiBoDe FROM BoDe WHERE MaBoDe = :id"),
#         {"id": ma_bo_de},
#     ).mappings().first()

#     if not bo_de:
#         raise HTTPException(status_code=404, detail="Không tìm thấy bộ đề.")

#     if bo_de["LoaiBoDe"] != "THI_CHINH_THUC":
#         raise HTTPException(status_code=400, detail="Chỉ hỗ trợ đánh giá đối với đề thi chính thức.")

#     stats = db.execute(
#         text("""
#             SELECT
#                 COUNT(*) AS TongLuotDanhGia,
#                 AVG(CAST(SoSao AS FLOAT)) AS DiemDoKhoTrungBinh
#             FROM DanhGiaBoDe
#             WHERE MaBoDe = :bo_de
#         """),
#         {"bo_de": ma_bo_de},
#     ).mappings().first()

#     has_completed = db.execute(
#         text("""
#             SELECT TOP 1 1
#             FROM LuotLamBai
#             WHERE MaNguoiDung = :me
#               AND MaBoDe = :bo_de
#               AND TrangThai IN ('DA_NOP', 'HET_GIO')
#         """),
#         {"me": me_id, "bo_de": ma_bo_de},
#     ).first() is not None

#     my_review = db.execute(
#         text("""
#             SELECT MaDanhGia, SoSao, BinhLuan, NgayDanhGia
#             FROM DanhGiaBoDe
#             WHERE MaBoDe = :bo_de AND MaNguoiDung = :me
#         """),
#         {"bo_de": ma_bo_de, "me": me_id},
#     ).mappings().first()

#     avg_val = round(float(stats["DiemDoKhoTrungBinh"]), 1) if stats and stats["DiemDoKhoTrungBinh"] is not None else None

#     return {
#         "MaBoDe": ma_bo_de,
#         "TieuDe": bo_de["TieuDe"],
#         "TongLuotDanhGia": stats["TongLuotDanhGia"] if stats else 0,
#         "DiemDoKhoTrungBinh": avg_val,
#         "NhanDoKhoTrungBinh": _get_difficulty_label(avg_val),
#         "CoTheDanhGia": has_completed,
#         "DanhGiaCuaToi": {
#             "MaDanhGia": my_review["MaDanhGia"],
#             "SoSao": my_review["SoSao"],
#             "NhanMucDo": DIFFICULTY_LABELS.get(my_review["SoSao"], "Trung bình"),
#             "GopY": my_review["BinhLuan"],
#             "NgayDanhGia": my_review["NgayDanhGia"].isoformat() if my_review["NgayDanhGia"] else None,
#         } if my_review else None,
#     }


# @router.post("/official/exams/{ma_bo_de}/review", status_code=status.HTTP_201_CREATED)
# def submit_or_update_official_exam_review(
#     ma_bo_de: int,
#     payload: ExamDifficultyReviewRequest,
#     current_user: dict = Depends(get_current_user),
#     db: Session = Depends(get_db),
# ):
#     """Thí sinh gửi/cập nhật mức độ khó (1-5) và góp ý sự cố đề thi chính thức (chỉ Admin xem được góp ý)"""
#     me_id = current_user["MaNguoiDung"]

#     bo_de = db.execute(
#         text("SELECT MaBoDe, LoaiBoDe FROM BoDe WHERE MaBoDe = :id AND TrangThai = 'CONG_KHAI'"),
#         {"id": ma_bo_de},
#     ).mappings().first()

#     if not bo_de:
#         raise HTTPException(status_code=404, detail="Không tìm thấy đề thi.")

#     if bo_de["LoaiBoDe"] != "THI_CHINH_THUC":
#         raise HTTPException(status_code=400, detail="Chỉ được đánh giá đối với đề thi chính thức.")

#     has_completed = db.execute(
#         text("""
#             SELECT TOP 1 1
#             FROM LuotLamBai
#             WHERE MaNguoiDung = :me
#               AND MaBoDe = :bo_de
#               AND TrangThai IN ('DA_NOP', 'HET_GIO')
#         """),
#         {"me": me_id, "bo_de": ma_bo_de},
#     ).first()

#     if not has_completed:
#         raise HTTPException(
#             status_code=403,
#             detail="Bạn cần hoàn thành bài thi chính thức này trước khi đánh giá và gửi góp ý.",
#         )

#     gop_y_clean = payload.BinhLuan.strip() if payload.BinhLuan and payload.BinhLuan.strip() else None

#     existing = db.execute(
#         text("SELECT MaDanhGia FROM DanhGiaBoDe WHERE MaBoDe = :bo_de AND MaNguoiDung = :me"),
#         {"bo_de": ma_bo_de, "me": me_id},
#     ).mappings().first()

#     if existing:
#         db.execute(
#             text("""
#                 UPDATE DanhGiaBoDe
#                 SET SoSao = :sao,
#                     BinhLuan = :gopy,
#                     NgayDanhGia = GETDATE()
#                 WHERE MaDanhGia = :id
#             """),
#             {"sao": payload.SoSao, "gopy": gop_y_clean, "id": existing["MaDanhGia"]},
#         )
#         msg = "Đã cập nhật đánh giá độ khó và góp ý của bạn!"
#     else:
#         db.execute(
#             text("""
#                 INSERT INTO DanhGiaBoDe (MaBoDe, MaNguoiDung, SoSao, BinhLuan, NgayDanhGia)
#                 VALUES (:bo_de, :me, :sao, :gopy, GETDATE())
#             """),
#             {"bo_de": ma_bo_de, "me": me_id, "sao": payload.SoSao, "gopy": gop_y_clean},
#         )
#         msg = "Cảm ơn bạn đã đánh giá độ khó và gửi góp ý cho quản trị viên!"

#     db.commit()

#     return {
#         "message": msg,
#         "SoSao": payload.SoSao,
#         "NhanMucDo": DIFFICULTY_LABELS.get(payload.SoSao, "Trung bình"),
#         "GopY": gop_y_clean,
#     }