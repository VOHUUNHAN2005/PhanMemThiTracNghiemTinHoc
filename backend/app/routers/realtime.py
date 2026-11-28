from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from firebase_admin import auth as firebase_auth
from sqlalchemy import text

from app.database import SessionLocal
from app.services.arena_manager import arena_manager

router = APIRouter(prefix="/ws", tags=["Realtime WebSocket"])


@router.websocket("/realtime")
async def websocket_realtime_endpoint(
    websocket: WebSocket,
    token: str = Query(..., description="Firebase ID Token"),
    device_id: str | None = Query(default=None, description="Unique Device ID"),
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
            text("""
                SELECT MaNguoiDung, TrangThaiTaiKhoan, MaThietBiHienTai
                FROM NguoiDung
                WHERE FirebaseUid = :uid
            """),
            {"uid": firebase_uid},
        ).mappings().first()
    finally:
        db.close()

    if not user or user["TrangThaiTaiKhoan"] != "HOAT_DONG":
        await websocket.close(code=4003, reason="Tài khoản không tồn tại hoặc đang bị khóa.")
        return

    active_device = (user.get("MaThietBiHienTai") or "").strip()
    clean_device = device_id.strip() if device_id else None
    if clean_device and active_device and clean_device != active_device:
        await websocket.close(code=4001, reason="Tài khoản đã đăng nhập trên thiết bị khác.")
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