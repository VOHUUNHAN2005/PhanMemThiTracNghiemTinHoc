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
        decoded_token = firebase_auth.verify_id_token(token, clock_skew_seconds=60)
        firebase_uid = decoded_token.get("uid")
    except Exception as e:
        print(f"[WS AUTH ERROR] Từ chối WebSocket: {repr(e)}")
        await websocket.close(code=4003, reason="Token không hợp lệ hoặc đã hết hạn.")
        return

    clean_device = device_id.strip() if device_id else None
    db = SessionLocal()
    try:
        user = db.execute(
            text("""
                SELECT MaNguoiDung, TrangThaiTaiKhoan
                FROM NguoiDung
                WHERE FirebaseUid = :uid
            """),
            {"uid": firebase_uid},
        ).mappings().first()

        if not user or user["TrangThaiTaiKhoan"] != "HOAT_DONG":
            await websocket.close(code=4003, reason="Tài khoản không tồn tại hoặc đang bị khóa.")
            return

        user_id = user["MaNguoiDung"]

        db.execute(
            text("""
                UPDATE NguoiDung
                SET MaThietBiHienTai = COALESCE(:device, MaThietBiHienTai),
                    TrangThaiOnline = 1,
                    HoatDongCuoi = SYSUTCDATETIME()
                WHERE MaNguoiDung = :id
            """),
            {"device": clean_device, "id": user_id},
        )
        db.commit()
    finally:
        db.close()

    old_ws = arena_manager.active_connections.get(user_id)
    if old_ws and old_ws is not websocket:
        try:
            await old_ws.close(code=4001, reason="Tài khoản đã đăng nhập trên thiết bị khác.")
        except Exception:
            pass

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