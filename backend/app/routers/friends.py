from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.friend import RespondFriendRequest, SendFriendRequest
from security import get_current_user

router = APIRouter(prefix="/api/friends", tags=["Friends"])


def _normalize_pair(user_a: int, user_b: int) -> tuple[int, int]:
    """Đảm bảo ràng buộc CK_KetBan_ChuanHoaCap: MaNguoiDung1 < MaNguoiDung2"""
    return (user_a, user_b) if user_a < user_b else (user_b, user_a)


# =========================================================================
# 1. TÌM KIẾM NGƯỜI CHƠI ĐỂ KẾT BẠN
# =========================================================================
@router.get("/search")
def search_users(
    q: str = Query(..., min_length=1, max_length=100, description="Tên đăng nhập, họ tên hoặc email"),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
    keyword = f"%{q.strip()}%"

    rows = db.execute(
        text("""
            SELECT TOP 20
                u.MaNguoiDung,
                u.TenDangNhap,
                u.HoTen,
                u.AnhDaiDien,
                u.SoCupHienTai,
                u.TrangThaiOnline,
                h.TenHang,
                kb.MaKetBan,
                kb.TrangThai AS TrangThaiKetBan,
                kb.MaNguoiGui
            FROM NguoiDung u
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            LEFT JOIN KetBan kb
                ON (kb.MaNguoiDung1 = CASE WHEN :me < u.MaNguoiDung THEN :me ELSE u.MaNguoiDung END)
               AND (kb.MaNguoiDung2 = CASE WHEN :me > u.MaNguoiDung THEN :me ELSE u.MaNguoiDung END)
            WHERE u.MaNguoiDung != :me
              AND u.TrangThaiTaiKhoan = 'HOAT_DONG'
              AND u.VaiTro = 'THI_SINH'
              AND (
                  u.TenDangNhap LIKE :kw
                  OR u.HoTen LIKE :kw
                  OR u.Email LIKE :kw
              )
            ORDER BY u.TrangThaiOnline DESC, u.SoCupHienTai DESC
        """),
        {"me": me_id, "kw": keyword},
    ).mappings().all()

    results = []
    for r in rows:
        quan_he = "CHUA_KET_BAN"
        if r["TrangThaiKetBan"] == "DA_KET_BAN":
            quan_he = "BAN_BE"
        elif r["TrangThaiKetBan"] == "CHO_DUYET":
            quan_he = "DA_GUI_LOI_MOI" if r["MaNguoiGui"] == me_id else "CHO_MINH_DUYET"

        results.append({
            "MaNguoiDung": r["MaNguoiDung"],
            "TenDangNhap": r["TenDangNhap"],
            "HoTen": r["HoTen"],
            "AnhDaiDien": r["AnhDaiDien"],
            "SoCupHienTai": r["SoCupHienTai"],
            "TenHang": r["TenHang"],
            "TrangThaiOnline": bool(r["TrangThaiOnline"]),
            "MaKetBan": r["MaKetBan"],
            "QuanHe": quan_he,
        })

    return results


# =========================================================================
# 2. DANH SÁCH BẠN BÈ
# =========================================================================
@router.get("/")
def get_my_friends(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    rows = db.execute(
        text("""
            SELECT
                kb.MaKetBan,
                kb.NgayCapNhat AS NgayKetBan,
                u.MaNguoiDung,
                u.TenDangNhap,
                u.HoTen,
                u.AnhDaiDien,
                u.SoCupHienTai,
                u.TrangThaiOnline,
                u.HoatDongCuoi,
                h.TenHang
            FROM KetBan kb
            INNER JOIN NguoiDung u
                ON u.MaNguoiDung = CASE
                    WHEN kb.MaNguoiDung1 = :me THEN kb.MaNguoiDung2
                    ELSE kb.MaNguoiDung1
                END
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE (kb.MaNguoiDung1 = :me OR kb.MaNguoiDung2 = :me)
              AND kb.TrangThai = 'DA_KET_BAN'
              AND u.TrangThaiTaiKhoan = 'HOAT_DONG'
            ORDER BY u.TrangThaiOnline DESC, u.SoCupHienTai DESC, u.HoTen ASC
        """),
        {"me": me_id},
    ).mappings().all()

    return [
        {
            "MaKetBan": r["MaKetBan"],
            "MaNguoiDung": r["MaNguoiDung"],
            "TenDangNhap": r["TenDangNhap"],
            "HoTen": r["HoTen"],
            "AnhDaiDien": r["AnhDaiDien"],
            "SoCupHienTai": r["SoCupHienTai"],
            "TenHang": r["TenHang"],
            "TrangThaiOnline": bool(r["TrangThaiOnline"]),
            "HoatDongCuoi": r["HoatDongCuoi"],
            "NgayKetBan": r["NgayKetBan"],
        }
        for r in rows
    ]


# =========================================================================
# 3. DANH SÁCH LỜI MỜI KẾT BẠN (ĐẾN & ĐÃ GỬI) + THÔNG BÁO KẾT BẠN
# =========================================================================
@router.get("/requests")
def get_friend_requests(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    rows = db.execute(
        text("""
            SELECT
                kb.MaKetBan,
                kb.MaNguoiGui,
                kb.NgayTao,
                u.MaNguoiDung,
                u.TenDangNhap,
                u.HoTen,
                u.AnhDaiDien,
                u.SoCupHienTai,
                u.TrangThaiOnline,
                h.TenHang
            FROM KetBan kb
            INNER JOIN NguoiDung u
                ON u.MaNguoiDung = CASE
                    WHEN kb.MaNguoiDung1 = :me THEN kb.MaNguoiDung2
                    ELSE kb.MaNguoiDung1
                END
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE (kb.MaNguoiDung1 = :me OR kb.MaNguoiDung2 = :me)
              AND kb.TrangThai = 'CHO_DUYET'
              AND u.TrangThaiTaiKhoan = 'HOAT_DONG'
            ORDER BY kb.NgayTao DESC
        """),
        {"me": me_id},
    ).mappings().all()

    incoming = []
    outgoing = []

    for r in rows:
        item = {
            "MaKetBan": r["MaKetBan"],
            "NgayTao": r["NgayTao"],
            "NguoiDung": {
                "MaNguoiDung": r["MaNguoiDung"],
                "TenDangNhap": r["TenDangNhap"],
                "HoTen": r["HoTen"],
                "AnhDaiDien": r["AnhDaiDien"],
                "SoCupHienTai": r["SoCupHienTai"],
                "TenHang": r["TenHang"],
                "TrangThaiOnline": bool(r["TrangThaiOnline"]),
            },
        }
        if r["MaNguoiGui"] == me_id:
            outgoing.append(item)
        else:
            incoming.append(item)

    return {
        "tong_loi_moi_den": len(incoming),
        "incoming": incoming,
        "outgoing": outgoing,
    }


@router.get("/notifications")
def get_friend_notifications(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lấy thông báo lời mời kết bạn trong bảng ThongBao"""
    me_id = current_user["MaNguoiDung"]

    rows = db.execute(
        text("""
            SELECT
                tb.MaThongBao,
                tb.LoaiThongBao,
                tb.TieuDe,
                tb.NoiDung,
                tb.MaThamChieu AS MaKetBan,
                tb.DaDoc,
                tb.NgayTao,
                kb.TrangThai AS TrangThaiLoiMoi
            FROM ThongBao tb
            LEFT JOIN KetBan kb
                ON tb.LoaiThongBao = 'LOI_MOI_KET_BAN'
               AND tb.MaThamChieu = kb.MaKetBan
            WHERE tb.MaNguoiNhan = :me
              AND tb.LoaiThongBao = 'LOI_MOI_KET_BAN'
            ORDER BY tb.NgayTao DESC
        """),
        {"me": me_id},
    ).mappings().all()

    unread_count = sum(1 for r in rows if not r["DaDoc"])

    return {
        "chua_doc": unread_count,
        "danh_sach": [
            {
                "MaThongBao": r["MaThongBao"],
                "TieuDe": r["TieuDe"],
                "NoiDung": r["NoiDung"],
                "MaKetBan": r["MaKetBan"],
                "TrangThaiLoiMoi": r["TrangThaiLoiMoi"],
                "DaDoc": bool(r["DaDoc"]),
                "NgayTao": r["NgayTao"],
            }
            for r in rows
        ],
    }


@router.put("/notifications/{ma_thong_bao}/read")
def mark_friend_notification_read(
    ma_thong_bao: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = db.execute(
        text("""
            UPDATE ThongBao
            SET DaDoc = 1
            WHERE MaThongBao = :tb_id AND MaNguoiNhan = :me
        """),
        {"tb_id": ma_thong_bao, "me": current_user["MaNguoiDung"]},
    )
    db.commit()

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo.")

    return {"message": "Đã đánh dấu đã đọc."}


# =========================================================================
# 4. GỬI LỜI MỜI KẾT BẠN
# =========================================================================
@router.post("/request", status_code=status.HTTP_201_CREATED)
def send_friend_request(
    payload: SendFriendRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
    target_id = payload.MaNguoiNhan

    if me_id == target_id:
        raise HTTPException(status_code=400, detail="Không thể tự gửi lời mời kết bạn cho chính mình.")

    target_user = db.execute(
        text("SELECT MaNguoiDung, TrangThaiTaiKhoan FROM NguoiDung WHERE MaNguoiDung = :id"),
        {"id": target_id},
    ).mappings().first()

    if not target_user or target_user["TrangThaiTaiKhoan"] != "HOAT_DONG":
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại hoặc đang bị khóa.")

    u1, u2 = _normalize_pair(me_id, target_id)

    existing = db.execute(
        text("""
            SELECT MaKetBan, MaNguoiGui, TrangThai
            FROM KetBan
            WHERE MaNguoiDung1 = :u1 AND MaNguoiDung2 = :u2
        """),
        {"u1": u1, "u2": u2},
    ).mappings().first()

    if existing:
        if existing["TrangThai"] == "DA_KET_BAN":
            raise HTTPException(status_code=409, detail="Hai bạn đã là bạn bè.")
        if existing["TrangThai"] == "CHO_DUYET":
            if existing["MaNguoiGui"] == me_id:
                raise HTTPException(status_code=409, detail="Bạn đã gửi lời mời kết bạn cho người này rồi.")
            raise HTTPException(
                status_code=409,
                detail="Người này đã gửi lời mời kết bạn cho bạn, hãy đồng ý lời mời.",
            )

        # Từng bị TU_CHOI -> cập nhật lại bản ghi cũ thành CHO_DUYET
        db.execute(
            text("""
                UPDATE KetBan
                SET MaNguoiGui = :me,
                    TrangThai = 'CHO_DUYET',
                    NgayTao = SYSUTCDATETIME(),
                    NgayCapNhat = NULL
                WHERE MaKetBan = :id
            """),
            {"me": me_id, "id": existing["MaKetBan"]},
        )
        ma_ket_ban = existing["MaKetBan"]
    else:
        ma_ket_ban = db.execute(
            text("""
                INSERT INTO KetBan (MaNguoiDung1, MaNguoiDung2, MaNguoiGui, TrangThai)
                OUTPUT INSERTED.MaKetBan
                VALUES (:u1, :u2, :me, 'CHO_DUYET')
            """),
            {"u1": u1, "u2": u2, "me": me_id},
        ).scalar()

    # Tạo thông báo trong bảng ThongBao cho người nhận
    db.execute(
        text("""
            INSERT INTO ThongBao (MaNguoiNhan, LoaiThongBao, TieuDe, NoiDung, MaThamChieu)
            VALUES (
                :nhan,
                'LOI_MOI_KET_BAN',
                N'Lời mời kết bạn mới',
                :noidung,
                :ref_id
            )
        """),
        {
            "nhan": target_id,
            "noidung": f"{current_user['HoTen']} (@{current_user['TenDangNhap']}) đã gửi lời mời kết bạn cho bạn.",
            "ref_id": ma_ket_ban,
        },
    )
    db.commit()

    return {
        "message": "Đã gửi lời mời kết bạn!",
        "MaKetBan": ma_ket_ban,
    }


# =========================================================================
# 5. ĐỒNG Ý HOẶC TỪ CHỐI LỜI MỜI KẾT BẠN
# =========================================================================
@router.post("/respond")
def respond_friend_request(
    payload: RespondFriendRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    kb = db.execute(
        text("""
            SELECT MaKetBan, MaNguoiDung1, MaNguoiDung2, MaNguoiGui, TrangThai
            FROM KetBan
            WHERE MaKetBan = :id
        """),
        {"id": payload.MaKetBan},
    ).mappings().first()

    if not kb:
        raise HTTPException(status_code=404, detail="Không tìm thấy lời mời kết bạn.")

    if me_id not in (kb["MaNguoiDung1"], kb["MaNguoiDung2"]):
        raise HTTPException(status_code=403, detail="Bạn không có quyền thao tác trên lời mời này.")

    if kb["MaNguoiGui"] == me_id:
        raise HTTPException(status_code=400, detail="Bạn không thể tự duyệt lời mời do chính mình gửi.")

    if kb["TrangThai"] != "CHO_DUYET":
        raise HTTPException(status_code=400, detail="Lời mời này đã được xử lý trước đó.")

    new_status = "DA_KET_BAN" if payload.ChapNhan else "TU_CHOI"

    db.execute(
        text("""
            UPDATE KetBan
            SET TrangThai = :st, NgayCapNhat = SYSUTCDATETIME()
            WHERE MaKetBan = :id
        """),
        {"st": new_status, "id": payload.MaKetBan},
    )

    # Đánh dấu đã đọc thông báo lời mời tương ứng
    db.execute(
        text("""
            UPDATE ThongBao
            SET DaDoc = 1
            WHERE MaNguoiNhan = :me
              AND LoaiThongBao = 'LOI_MOI_KET_BAN'
              AND MaThamChieu = :ref_id
        """),
        {"me": me_id, "ref_id": payload.MaKetBan},
    )

    if payload.ChapNhan:
        db.execute(
            text("""
                INSERT INTO ThongBao (MaNguoiNhan, LoaiThongBao, TieuDe, NoiDung, MaThamChieu)
                VALUES (
                    :gui,
                    'HE_THONG',
                    N'Đã chấp nhận lời mời kết bạn',
                    :noidung,
                    :ref_id
                )
            """),
            {
                "gui": kb["MaNguoiGui"],
                "noidung": f"{current_user['HoTen']} đã đồng ý lời mời kết bạn của bạn.",
                "ref_id": payload.MaKetBan,
            },
        )

    db.commit()

    return {
        "message": "Đã đồng ý kết bạn!" if payload.ChapNhan else "Đã từ chối lời mời kết bạn.",
        "TrangThai": new_status,
    }


# =========================================================================
# 6. HỦY LỜI MỜI ĐÃ GỬI (Dành cho người gửi khi đang CHO_DUYET)
# =========================================================================
@router.delete("/request/{target_user_id}")
def cancel_sent_friend_request(
    target_user_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
    u1, u2 = _normalize_pair(me_id, target_user_id)

    kb = db.execute(
        text("""
            SELECT MaKetBan, MaNguoiGui, TrangThai
            FROM KetBan
            WHERE MaNguoiDung1 = :u1 AND MaNguoiDung2 = :u2
        """),
        {"u1": u1, "u2": u2},
    ).mappings().first()

    if not kb or kb["TrangThai"] != "CHO_DUYET":
        raise HTTPException(status_code=404, detail="Không có lời mời kết bạn nào đang chờ duyệt.")

    if kb["MaNguoiGui"] != me_id:
        raise HTTPException(status_code=403, detail="Bạn không phải người gửi lời mời này.")

    # Xóa thông báo chưa xử lý bên người nhận & xóa bản ghi KetBan
    db.execute(
        text("""
            DELETE FROM ThongBao
            WHERE MaNguoiNhan = :target
              AND LoaiThongBao = 'LOI_MOI_KET_BAN'
              AND MaThamChieu = :ref_id
        """),
        {"target": target_user_id, "ref_id": kb["MaKetBan"]},
    )
    db.execute(text("DELETE FROM KetBan WHERE MaKetBan = :id"), {"id": kb["MaKetBan"]})
    db.commit()

    return {"message": "Đã hủy lời mời kết bạn."}


# =========================================================================
# 7. XÓA / HỦY KẾT BẠN (Khi đã là DA_KET_BAN)
# =========================================================================
@router.delete("/{friend_user_id}")
def unfriend_user(
    friend_user_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
    u1, u2 = _normalize_pair(me_id, friend_user_id)

    kb = db.execute(
        text("""
            SELECT MaKetBan, TrangThai
            FROM KetBan
            WHERE MaNguoiDung1 = :u1 AND MaNguoiDung2 = :u2
        """),
        {"u1": u1, "u2": u2},
    ).mappings().first()

    if not kb or kb["TrangThai"] != "DA_KET_BAN":
        raise HTTPException(status_code=404, detail="Hai người hiện chưa phải là bạn bè.")

    db.execute(text("DELETE FROM KetBan WHERE MaKetBan = :id"), {"id": kb["MaKetBan"]})
    db.commit()

    return {"message": "Đã hủy kết bạn."}


# =========================================================================
# 8. XEM HỒ SƠ CỦA BẠN BÈ (HOẶC NGƯỜI CHƠI KHÁC)
# =========================================================================
@router.get("/profile/{target_user_id}")
def get_friend_profile(
    target_user_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
    u1, u2 = _normalize_pair(me_id, target_user_id)

    # 1. Lấy thông tin cơ bản + hạng
    user_row = db.execute(
        text("""
            SELECT
                u.MaNguoiDung,
                u.TenDangNhap,
                u.HoTen,
                u.AnhDaiDien,
                u.SoCupHienTai,
                u.MaHangHienTai,
                h.TenHang,
                u.TrangThaiOnline,
                u.HoatDongCuoi,
                u.NgayTao
            FROM NguoiDung u
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE u.MaNguoiDung = :target
              AND u.TrangThaiTaiKhoan = 'HOAT_DONG'
              AND u.VaiTro = 'THI_SINH'
        """),
        {"target": target_user_id},
    ).mappings().first()

    if not user_row:
        raise HTTPException(status_code=404, detail="Không tìm thấy hồ sơ người dùng.")

    # 2. Kiểm tra trạng thái quan hệ bạn bè với mình
    kb = db.execute(
        text("""
            SELECT MaKetBan, MaNguoiGui, TrangThai, NgayCapNhat
            FROM KetBan
            WHERE MaNguoiDung1 = :u1 AND MaNguoiDung2 = :u2
        """),
        {"u1": u1, "u2": u2},
    ).mappings().first()

    quan_he = "CHUA_KET_BAN"
    if me_id == target_user_id:
        quan_he = "CHINH_MINH"
    elif kb:
        if kb["TrangThai"] == "DA_KET_BAN":
            quan_he = "BAN_BE"
        elif kb["TrangThai"] == "CHO_DUYET":
            quan_he = "DA_GUI_LOI_MOI" if kb["MaNguoiGui"] == me_id else "CHO_MINH_DUYET"

    # 3. Thống kê thành tích thi đấu & luyện tập của người đó
    stats_arena = db.execute(
        text("""
            SELECT
                COUNT(*) AS TongTranDau,
                SUM(CASE WHEN ThuHang = 1 THEN 1 ELSE 0 END) AS SoTranThang
            FROM ThanhVienPhongDau
            WHERE MaNguoiDung = :target
              AND TrangThai = 'HOAN_THANH'
        """),
        {"target": target_user_id},
    ).mappings().first()

    stats_exam = db.execute(
        text("""
            SELECT
                COUNT(*) AS TongLuotThi,
                SUM(CASE WHEN DaDat = 1 THEN 1 ELSE 0 END) AS SoLuotDat
            FROM LuotLamBai
            WHERE MaNguoiDung = :target
              AND TrangThai IN ('DA_NOP', 'HET_GIO')
        """),
        {"target": target_user_id},
    ).mappings().first()

    # 4. Top 5 biến động cúp gần nhất (nếu đã là bạn bè thì cho xem chi tiết)
    cup_history = []
    if quan_he in ("BAN_BE", "CHINH_MINH"):
        history_rows = db.execute(
            text("""
                SELECT TOP 5
                    MaBienDong,
                    LoaiBienDong,
                    SoCupThayDoi,
                    MoTa,
                    NgayTao
                FROM LichSuBienDongCup
                WHERE MaNguoiDung = :target
                ORDER BY NgayTao DESC
            """),
            {"target": target_user_id},
        ).mappings().all()

        cup_history = [
            {
                "MaBienDong": h["MaBienDong"],
                "LoaiBienDong": h["LoaiBienDong"],
                "SoCupThayDoi": h["SoCupThayDoi"],
                "MoTa": h["MoTa"],
                "NgayTao": h["NgayTao"],
            }
            for h in history_rows
        ]

    return {
        "MaNguoiDung": user_row["MaNguoiDung"],
        "TenDangNhap": user_row["TenDangNhap"],
        "HoTen": user_row["HoTen"],
        "AnhDaiDien": user_row["AnhDaiDien"],
        "SoCupHienTai": user_row["SoCupHienTai"],
        "TenHang": user_row["TenHang"],
        "TrangThaiOnline": bool(user_row["TrangThaiOnline"]),
        "HoatDongCuoi": user_row["HoatDongCuoi"],
        "NgayThamGia": user_row["NgayTao"],
        "QuanHe": quan_he,
        "MaKetBan": kb["MaKetBan"] if kb else None,
        "ThongKe": {
            "TongTranDau": stats_arena["TongTranDau"] or 0,
            "SoTranThang": stats_arena["SoTranThang"] or 0,
            "TongLuotThi": stats_exam["TongLuotThi"] or 0,
            "SoLuotDat": stats_exam["SoLuotDat"] or 0,
        },
        "LichSuCupGanDay": cup_history,
    }