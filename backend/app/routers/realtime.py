import json
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from firebase_admin import auth as firebase_auth
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import SessionLocal, get_db
from app.services.arena_manager import arena_manager
from security import get_current_user

router = APIRouter(tags=["Realtime & Arena"])


class CreateArenaRoomRequest(BaseModel):
    LoaiPhong: str = Field(..., pattern="^(DOI_KHANG_1VS1|GIAI_DAU_NN)$")
    MaChuDe: int = Field(..., gt=0)
    MatKhauPhong: str | None = Field(default=None, max_length=50)


class InviteFriendRequest(BaseModel):
    MaNguoiDuocMoi: int = Field(..., gt=0)


class JoinRoomRequest(BaseModel):
    MaPhong: int | None = Field(default=None, gt=0)
    MaCodePhong: str | None = Field(default=None, min_length=4, max_length=20)
    MatKhauPhong: str | None = Field(default=None)





@router.websocket("/ws/realtime")
async def websocket_realtime_endpoint(
    websocket: WebSocket,
    token: str = Query(..., description="Firebase ID Token"),
):
    try:
        decoded = firebase_auth.verify_id_token(token)
        firebase_uid = decoded.get("uid")
    except Exception:
        await websocket.close(code=4003, reason="Token không hợp lệ.")
        return

    db = SessionLocal()
    try:
        user = db.execute(
            text("SELECT MaNguoiDung, TrangThaiTaiKhoan FROM NguoiDung WHERE FirebaseUid = :uid"),
            {"uid": firebase_uid},
        ).mappings().first()
    finally:
        db.close()

    if not user or user["TrangThaiTaiKhoan"] != "HOAT_DONG":
        await websocket.close(code=4003, reason="Tài khoản không tồn tại hoặc đang bị khóa.")
        return

    user_id = user["MaNguoiDung"]
    await arena_manager.connect(user_id, websocket)

    try:
        while True:
            msg = await websocket.receive_json()
            action = msg.get("action")
            payload = msg.get("data") or {}

            if action == "PING":
                await arena_manager.send_personal(user_id, "PONG", {})

            elif action == "FIND_1VS1":
                ma_chu_de = int(payload.get("MaChuDe", 0))
                if ma_chu_de <= 0:
                    await arena_manager.send_personal(user_id, "ERROR", {"message": "Vui lòng chọn chủ đề trước khi tìm trận 1vs1."})
                else:
                    await arena_manager.join_random_1vs1_queue(user_id, ma_chu_de)

            elif action == "CANCEL_FIND_1VS1":
                arena_manager.remove_from_duel_queue(user_id)
                await arena_manager.send_personal(user_id, "SEARCH_1VS1_CANCELLED", {})

            elif action == "SET_READY":
                ready = bool(payload.get("SanSang", True))
                await arena_manager.toggle_ready(user_id, ready)

            elif action == "START_ROOM":
                try:
                    await arena_manager.start_room(user_id)
                except ValueError as e:
                    await arena_manager.send_personal(user_id, "ERROR", {"message": str(e)})

            elif action == "SUBMIT_ANSWER":
                ma_cau_hoi = int(payload.get("MaCauHoi", 0))
                selected = [int(x) for x in payload.get("DanhSachMaDapAn", [])]
                await arena_manager.handle_submit_answer(user_id, ma_cau_hoi, selected)

            elif action == "LEAVE_ROOM":
                ma_phong = arena_manager.user_room_map.get(user_id)
                if ma_phong:
                    await arena_manager.handle_leave_or_forfeit(ma_phong, user_id, is_cheat=False)

            elif action == "CHEAT_DETECTED":
                ma_phong = arena_manager.user_room_map.get(user_id)
                reason = str(payload.get("LyDo", "Gian lận trong thi đấu"))
                if ma_phong:
                    await arena_manager.handle_leave_or_forfeit(
                        ma_phong, user_id, is_cheat=True, cheat_reason=reason
                    )

    except WebSocketDisconnect:
        await arena_manager.disconnect(user_id)
    except Exception:
        await arena_manager.disconnect(user_id)





@router.post("/api/arena/rooms")
async def create_arena_room(
    payload: CreateArenaRoomRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        return await arena_manager.create_room(
            host_id=current_user["MaNguoiDung"],
            loai_phong=payload.LoaiPhong,
            ma_chu_de=payload.MaChuDe,
            mat_khau_phong=payload.MatKhauPhong,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/api/arena/rooms/open")
def list_open_rooms(
    loai_phong: str | None = Query(None, pattern="^(DOI_KHANG_1VS1|GIAI_DAU_NN)$"),
    current_user: dict = Depends(get_current_user),
):
    """Danh sách phòng đang ở trạng thái CHO_NGUOI_CHOI"""
    result = []
    for room in arena_manager.rooms.values():
        if room.status != "CHO_NGUOI_CHOI":
            continue
        if loai_phong and room.loai_phong != loai_phong:
            continue
        host = room.players.get(room.ma_chu_phong)
        result.append({
            "MaPhong": room.ma_phong,
            "MaCodePhong": room.ma_code_phong,
            "LoaiPhong": room.loai_phong,
            "MaChuDe": room.ma_chu_de,
            "TenChuDe": room.ten_chu_de,
            "CoMatKhau": bool(room.mat_khau_phong),
            "TongSoCau": len(room.questions),
            "SoNguoiHienTai": len(room.players),
            "ChuPhong": host.ho_ten if host else "",
        })
    return result


@router.post("/api/arena/rooms/join")
async def join_arena_room(
    payload: JoinRoomRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    target_ma_phong = payload.MaPhong
    if not target_ma_phong and payload.MaCodePhong:
        code = payload.MaCodePhong.strip().upper()
        row = db.execute(
            text("SELECT MaPhong FROM PhongThiDau WHERE MaCodePhong = :code AND TrangThai = 'CHO_NGUOI_CHOI'"),
            {"code": code},
        ).first()
        if not row:
            raise HTTPException(status_code=404, detail="Không tìm thấy phòng chờ với mã này.")
        target_ma_phong = row[0]

    if not target_ma_phong:
        raise HTTPException(status_code=400, detail="Vui lòng cung cấp Mã phòng hoặc ID phòng.")

    try:
        lobby = await arena_manager.join_room(
            user_id=current_user["MaNguoiDung"],
            ma_phong=target_ma_phong,
            mat_khau=payload.MatKhauPhong,
        )
        return {"message": "Tham gia phòng thành công!", "Phong": lobby}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/api/arena/rooms/invite")
async def invite_friend_to_arena(
    payload: InviteFriendRequest,
    current_user: dict = Depends(get_current_user),
):
    try:
        invite = await arena_manager.invite_friend(
            host_id=current_user["MaNguoiDung"],
            target_user_id=payload.MaNguoiDuocMoi,
        )
        return {"message": "Đã gửi lời mời vào phòng!", "LoiMoi": invite}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/api/arena/rooms/kick/{target_user_id}")
async def kick_player_from_room(
    target_user_id: int,
    current_user: dict = Depends(get_current_user),
):
    try:
        await arena_manager.kick_player(
            host_id=current_user["MaNguoiDung"],
            target_user_id=target_user_id,
        )
        return {"message": "Đã mời người chơi ra khỏi phòng."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))





@router.get("/api/arena/history")
def get_my_arena_history(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]
    rows = db.execute(
        text("""
            SELECT TOP 40
                p.MaPhong,
                p.MaCodePhong,
                p.LoaiPhong,
                p.CheDoGhep,
                p.TrangThai AS TrangThaiPhong,
                p.ThoiGianBatDau,
                p.ThoiGianKetThuc,
                tv.MaThanhVienPhong,
                tv.TrangThai AS TrangThaiCaNhan,
                tv.SoCauDung,
                tv.TongThoiGianTraLoiMs,
                tv.ThuHang,
                tv.CupThayDoi
            FROM ThanhVienPhongDau tv
            INNER JOIN PhongThiDau p ON tv.MaPhong = p.MaPhong
            WHERE tv.MaNguoiDung = :me
              AND p.TrangThai IN ('DA_KET_THUC', 'DA_HUY')
            ORDER BY p.ThoiGianKetThuc DESC
        """),
        {"me": me_id},
    ).mappings().all()

    return [dict(r) for r in rows]


@router.get("/api/arena/history/{ma_phong}/review")
def review_arena_match_detail(
    ma_phong: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Xem lại toàn bộ câu hỏi & đáp án đã chọn trong trận đấu (Khóa nếu phòng chưa xong hết)"""
    me_id = current_user["MaNguoiDung"]

    room_row = db.execute(
        text("""
            SELECT MaPhong, MaCodePhong, LoaiPhong, DanhSachCauHoiJson, TrangThai
            FROM PhongThiDau
            WHERE MaPhong = :phong
        """),
        {"phong": ma_phong},
    ).mappings().first()

    if not room_row:
        raise HTTPException(status_code=404, detail="Không tìm thấy phòng đấu.")


    if room_row["TrangThai"] not in ("DA_KET_THUC", "DA_HUY") or ma_phong in arena_manager.rooms:
        raise HTTPException(
            status_code=403,
            detail="Trận đấu chưa kết thúc hoàn toàn. Chỉ được xem lại đáp án sau khi tất cả thí sinh đã hoàn thành!",
        )

    member = db.execute(
        text("""
            SELECT MaThanhVienPhong, SoCauDung, TongThoiGianTraLoiMs, ThuHang, CupThayDoi, TrangThai
            FROM ThanhVienPhongDau
            WHERE MaPhong = :phong AND MaNguoiDung = :me
        """),
        {"phong": ma_phong, "me": me_id},
    ).mappings().first()

    if not member:
        raise HTTPException(status_code=403, detail="Bạn không tham gia phòng đấu này.")

    q_meta_list = json.loads(room_row["DanhSachCauHoiJson"] or "[]")
    if not q_meta_list:
        return {"MaPhong": ma_phong, "CauHoi": []}

    q_ids = [item["MaCauHoi"] for item in q_meta_list]
    placeholders = ", ".join([f":q_{i}" for i in range(len(q_ids))])
    q_params = {f"q_{i}": qid for i, qid in enumerate(q_ids)}

    q_rows = db.execute(
        text(f"""
            SELECT ch.MaCauHoi, ch.NoiDung, ch.HinhAnhUrl, ch.MucDo, lch.ChoPhepNhieuDapAn
            FROM CauHoi ch
            INNER JOIN LoaiCauHoi lch ON ch.MaLoaiCauHoi = lch.MaLoaiCauHoi
            WHERE ch.MaCauHoi IN ({placeholders})
        """),
        q_params,
    ).mappings().all()
    q_info_map = {r["MaCauHoi"]: dict(r) for r in q_rows}

    ans_rows = db.execute(
        text(f"""
            SELECT MaDapAn, MaCauHoi, NoiDung, LaDapAnDung, ThuTuHienThi
            FROM DapAn
            WHERE MaCauHoi IN ({placeholders})
            ORDER BY ThuTuHienThi ASC
        """),
        q_params,
    ).mappings().all()
    ans_map = {}
    for a in ans_rows:
        ans_map.setdefault(a["MaCauHoi"], []).append(dict(a))

    user_choices = db.execute(
        text("""
            SELECT MaCauHoi, MaDapAn, ThoiGianPhanHoiMs
            FROM ChiTietTraLoiPhongDau
            WHERE MaThanhVienPhong = :mtv
        """),
        {"mtv": member["MaThanhVienPhong"]},
    ).mappings().all()
    chosen_map = {}
    time_map = {}
    for c in user_choices:
        chosen_map.setdefault(c["MaCauHoi"], set()).add(c["MaDapAn"])
        time_map[c["MaCauHoi"]] = c["ThoiGianPhanHoiMs"]

    review_questions = []
    for meta in q_meta_list:
        qid = meta["MaCauHoi"]
        qinfo = q_info_map.get(qid)
        if not qinfo:
            continue
        opts = ans_map.get(qid, [])
        selected_ids = chosen_map.get(qid, set())
        correct_ids = {o["MaDapAn"] for o in opts if o["LaDapAnDung"]}
        is_right = len(correct_ids) > 0 and selected_ids == correct_ids

        review_questions.append({
            "ThuTuCau": meta["ThuTuCau"],
            "MaCauHoi": qid,
            "NoiDung": qinfo["NoiDung"],
            "HinhAnhUrl": qinfo["HinhAnhUrl"],
            "MucDo": qinfo["MucDo"],
            "TraLoiDung": is_right,
            "ThoiGianPhanHoiMs": time_map.get(qid),
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

    return {
        "MaPhong": ma_phong,
        "MaCodePhong": room_row["MaCodePhong"],
        "LoaiPhong": room_row["LoaiPhong"],
        "KetQuaCaNhan": dict(member),
        "CauHoi": review_questions,
    }





@router.get("/api/leaderboard")
def get_cup_leaderboard(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    me_id = current_user["MaNguoiDung"]

    top_rows = db.execute(
        text("""
            SELECT TOP 50
                u.MaNguoiDung,
                u.TenDangNhap,
                u.HoTen,
                u.AnhDaiDien,
                u.SoCupHienTai,
                u.TrangThaiOnline,
                h.TenHang,
                h.ThuTuHang
            FROM NguoiDung u
            INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
            WHERE u.VaiTro = 'THI_SINH' AND u.TrangThaiTaiKhoan = 'HOAT_DONG'
            ORDER BY u.SoCupHienTai DESC, u.MaNguoiDung ASC
        """)
    ).mappings().all()

    my_rank = db.execute(
        text("""
            SELECT COUNT(*) + 1
            FROM NguoiDung
            WHERE VaiTro = 'THI_SINH'
              AND TrangThaiTaiKhoan = 'HOAT_DONG'
              AND SoCupHienTai > (SELECT ISNULL(SoCupHienTai, 0) FROM NguoiDung WHERE MaNguoiDung = :me)
        """),
        {"me": me_id},
    ).scalar()

    return {
        "HangCuaToi": my_rank,
        "SoCupCuaToi": current_user["SoCupHienTai"],
        "TenHangCuaToi": current_user["TenHang"],
        "TopNguoiChoi": [
            {
                "ThuHang": idx,
                "MaNguoiDung": r["MaNguoiDung"],
                "TenDangNhap": r["TenDangNhap"],
                "HoTen": r["HoTen"],
                "AnhDaiDien": r["AnhDaiDien"],
                "SoCupHienTai": r["SoCupHienTai"],
                "TenHang": r["TenHang"],
                "TrangThaiOnline": bool(r["TrangThaiOnline"]),
            }
            for idx, r in enumerate(top_rows, start=1)
        ],
    }
