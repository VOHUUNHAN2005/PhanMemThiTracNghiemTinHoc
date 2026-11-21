import asyncio
import json
import math
import random
import string
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from fastapi import WebSocket
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import SessionLocal


QUESTIONS_COUNT_1VS1 = 20
QUESTIONS_COUNT_TOURNAMENT = 50
MIN_COMPLETION_RATIO = 0.30


DIFFICULTY_SECONDS = {
    "DE": 15,
    "TRUNG_BINH": 20,
    "KHO": 30,
}


CUP_1VS1_WIN = 50
CUP_1VS1_LOSE = 25
CUP_1VS1_OPPONENT_LEFT = 25
CUP_TOURNAMENT_TOP = {1: 100, 2: 70, 3: 50}
CUP_TOURNAMENT_OTHER = 25


@dataclass
class PlayerRuntime:
    user_id: int
    ma_thanh_vien_phong: int
    ho_ten: str
    anh_dai_dien: Optional[str]
    so_cup: int
    ten_hang: str
    is_ready: bool = False
    correct_count: int = 0
    wrong_count: int = 0
    answered_count: int = 0
    total_time_ms: int = 0

    answered_current: bool = False

    current_q_index: int = 0
    question_started_at: float = 0.0
    personal_timer_task: Optional[asyncio.Task] = None
    finished: bool = False
    left_or_forfeited: bool = False
    cheated: bool = False


@dataclass
class ActiveRoomRuntime:
    ma_phong: int
    ma_code_phong: str
    loai_phong: str
    che_do_ghep: str
    ma_chu_phong: int
    ma_chu_de: int
    ten_chu_de: str
    mat_khau_phong: Optional[str]
    questions: List[dict]
    players: Dict[int, PlayerRuntime] = field(default_factory=dict)
    kicked_users: set = field(default_factory=set)
    status: str = "CHO_NGUOI_CHOI"

    shared_q_index: int = 0
    shared_q_started_at: float = 0.0
    shared_timer_task: Optional[asyncio.Task] = None


class ArenaRealtimeManager:
    def __init__(self):
        self.active_connections: Dict[int, WebSocket] = {}

        self.duel_queues: Dict[int, List[int]] = {}
        self.rooms: Dict[int, ActiveRoomRuntime] = {}
        self.user_room_map: Dict[int, int] = {}




    async def connect(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        old_ws = self.active_connections.get(user_id)
        if old_ws and old_ws != websocket:
            try:
                await old_ws.close(code=4001, reason="Tài khoản đăng nhập ở thiết bị khác.")
            except Exception:
                pass

        self.active_connections[user_id] = websocket
        self._set_user_online_db(user_id, True)
        await self._notify_friends_presence(user_id, is_online=True)

    async def disconnect(self, user_id: int):
        self.active_connections.pop(user_id, None)
        self.remove_from_duel_queue(user_id)
        self._set_user_online_db(user_id, False)
        await self._notify_friends_presence(user_id, is_online=False)

        ma_phong = self.user_room_map.get(user_id)
        if ma_phong and ma_phong in self.rooms:
            await self.handle_leave_or_forfeit(ma_phong, user_id, is_cheat=False)

    async def send_personal(self, user_id: int, event: str, data: dict):
        ws = self.active_connections.get(user_id)
        if ws:
            try:
                await ws.send_json({"event": event, "data": data})
            except Exception:
                pass

    async def broadcast_room(self, room: ActiveRoomRuntime, event: str, data: dict, exclude_user: Optional[int] = None):
        for uid in list(room.players.keys()):
            if exclude_user and uid == exclude_user:
                continue
            await self.send_personal(uid, event, data)

    def _set_user_online_db(self, user_id: int, is_online: bool):
        db = SessionLocal()
        try:
            db.execute(
                text("""
                    UPDATE NguoiDung
                    SET TrangThaiOnline = :st, HoatDongCuoi = SYSUTCDATETIME()
                    WHERE MaNguoiDung = :uid
                """),
                {"st": 1 if is_online else 0, "uid": user_id},
            )
            db.commit()
        finally:
            db.close()

    async def _notify_friends_presence(self, user_id: int, is_online: bool):
        db = SessionLocal()
        try:
            rows = db.execute(
                text("""
                    SELECT CASE WHEN MaNguoiDung1 = :me THEN MaNguoiDung2 ELSE MaNguoiDung1 END
                    FROM KetBan
                    WHERE (MaNguoiDung1 = :me OR MaNguoiDung2 = :me) AND TrangThai = 'DA_KET_BAN'
                """),
                {"me": user_id},
            ).all()
            friend_ids = [r[0] for r in rows]
        finally:
            db.close()

        for fid in friend_ids:
            if fid in self.active_connections:
                await self.send_personal(
                    fid,
                    "FRIEND_PRESENCE",
                    {"MaNguoiDung": user_id, "TrangThaiOnline": is_online},
                )




    def _generate_room_code(self, db: Session) -> str:
        while True:
            code = "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
            exists = db.execute(
                text("SELECT 1 FROM PhongThiDau WHERE MaCodePhong = :code"),
                {"code": code},
            ).first()
            if not exists:
                return code

    def _pick_topic_questions(self, db: Session, ma_chu_de: int, required_count: int) -> tuple[str, List[dict]]:
        topic = db.execute(
            text("SELECT MaChuDe, TenChuDe FROM ChuDe WHERE MaChuDe = :cd"),
            {"cd": ma_chu_de},
        ).mappings().first()
        if not topic:
            raise ValueError("Không tìm thấy chủ đề được chọn.")

        total_available = db.execute(
            text("SELECT COUNT(*) FROM CauHoi WHERE MaChuDe = :cd AND TrangThai = 'HOAT_DONG'"),
            {"cd": ma_chu_de},
        ).scalar() or 0

        if total_available < required_count:
            raise ValueError(
                f"Chủ đề '{topic['TenChuDe']}' hiện chỉ có {total_available}/{required_count} câu hỏi hoạt động. "
                f"Không đủ {required_count} câu để mở phòng!"
            )

        q_rows = db.execute(
            text("""
                SELECT TOP (:limit)
                    ch.MaCauHoi, ch.NoiDung, ch.HinhAnhUrl, ch.MucDo,
                    lch.ChoPhepNhieuDapAn
                FROM CauHoi ch
                INNER JOIN LoaiCauHoi lch ON ch.MaLoaiCauHoi = lch.MaLoaiCauHoi
                WHERE ch.MaChuDe = :cd AND ch.TrangThai = 'HOAT_DONG'
                ORDER BY NEWID()
            """),
            {"limit": required_count, "cd": ma_chu_de},
        ).mappings().all()

        q_ids = [r["MaCauHoi"] for r in q_rows]
        placeholders = ", ".join([f":q_{i}" for i in range(len(q_ids))])
        ans_params = {f"q_{i}": qid for i, qid in enumerate(q_ids)}

        ans_rows = db.execute(
            text(f"""
                SELECT MaDapAn, MaCauHoi, NoiDung, LaDapAnDung, ThuTuHienThi
                FROM DapAn
                WHERE MaCauHoi IN ({placeholders})
                ORDER BY ThuTuHienThi ASC
            """),
            ans_params,
        ).mappings().all()

        ans_by_q: Dict[int, List[dict]] = {qid: [] for qid in q_ids}
        correct_by_q: Dict[int, List[int]] = {qid: [] for qid in q_ids}
        for a in ans_rows:
            ans_by_q[a["MaCauHoi"]].append({
                "MaDapAn": a["MaDapAn"],
                "NoiDung": a["NoiDung"],
                "ThuTuHienThi": a["ThuTuHienThi"],
            })
            if a["LaDapAnDung"]:
                correct_by_q[a["MaCauHoi"]].append(a["MaDapAn"])

        questions = []
        for idx, q in enumerate(q_rows, start=1):
            qid = q["MaCauHoi"]
            muc_do = q["MucDo"]
            thoi_gian = DIFFICULTY_SECONDS.get(muc_do, 15)
            questions.append({
                "ThuTuCau": idx,
                "MaCauHoi": qid,
                "NoiDung": q["NoiDung"],
                "HinhAnhUrl": q["HinhAnhUrl"],
                "MucDo": muc_do,
                "ThoiGianGiay": thoi_gian,
                "ChoPhepNhieuDapAn": bool(q["ChoPhepNhieuDapAn"]),
                "DapAn": ans_by_q[qid],
                "correct_ids": correct_by_q[qid],
            })

        return topic["TenChuDe"], questions

    def _get_user_brief(self, db: Session, user_id: int) -> dict:
        row = db.execute(
            text("""
                SELECT u.MaNguoiDung, u.HoTen, u.AnhDaiDien, u.SoCupHienTai, h.TenHang
                FROM NguoiDung u
                INNER JOIN CapBacHang h ON u.MaHangHienTai = h.MaHang
                WHERE u.MaNguoiDung = :uid
            """),
            {"uid": user_id},
        ).mappings().first()
        return dict(row)




    async def create_room(
        self,
        host_id: int,
        loai_phong: str,
        ma_chu_de: int,
        mat_khau_phong: Optional[str] = None,
    ) -> dict:
        if host_id in self.user_room_map:
            raise ValueError("Bạn đang ở trong một phòng đấu khác.")

        required_q = QUESTIONS_COUNT_1VS1 if loai_phong == "DOI_KHANG_1VS1" else QUESTIONS_COUNT_TOURNAMENT
        clean_pwd = mat_khau_phong.strip() if (mat_khau_phong and mat_khau_phong.strip()) else None

        db = SessionLocal()
        try:
            ten_chu_de, questions = self._pick_topic_questions(db, ma_chu_de, required_q)
            code = self._generate_room_code(db)


            q_json_str = json.dumps(
                [
                    {
                        "ThuTuCau": q["ThuTuCau"],
                        "MaCauHoi": q["MaCauHoi"],
                        "MucDo": q["MucDo"],
                        "ThoiGianGiay": q["ThoiGianGiay"],
                    }
                    for q in questions
                ],
                ensure_ascii=False,
            )

            ma_phong = db.execute(
                text("""
                    INSERT INTO PhongThiDau (
                        MaCodePhong, LoaiPhong, CheDoGhep, MaChuPhong,
                        MaBoDe, ThoiGianMoiCau, MatKhauPhong,
                        DanhSachCauHoiJson, TrangThai
                    )
                    OUTPUT INSERTED.MaPhong
                    VALUES (
                        :code, :loai, 'MOI_BAN_BE', :host,
                        NULL, 15, :pwd,
                        :qjson, 'CHO_NGUOI_CHOI'
                    )
                """),
                {
                    "code": code,
                    "loai": loai_phong,
                    "host": host_id,
                    "pwd": clean_pwd,
                    "qjson": q_json_str,
                },
            ).scalar()

            brief = self._get_user_brief(db, host_id)
            mtv = db.execute(
                text("""
                    INSERT INTO ThanhVienPhongDau (
                        MaPhong, MaNguoiDung, TrangThai, SoCauDung, TongThoiGianTraLoiMs
                    )
                    OUTPUT INSERTED.MaThanhVienPhong
                    VALUES (:phong, :uid, 'SAN_SANG', 0, 0)
                """),
                {"phong": ma_phong, "uid": host_id},
            ).scalar()
            db.commit()

            room = ActiveRoomRuntime(
                ma_phong=ma_phong,
                ma_code_phong=code,
                loai_phong=loai_phong,
                che_do_ghep="MOI_BAN_BE",
                ma_chu_phong=host_id,
                ma_chu_de=ma_chu_de,
                ten_chu_de=ten_chu_de,
                mat_khau_phong=clean_pwd,
                questions=questions,
                status="CHO_NGUOI_CHOI",
            )
            room.players[host_id] = PlayerRuntime(
                user_id=host_id,
                ma_thanh_vien_phong=mtv,
                ho_ten=brief["HoTen"],
                anh_dai_dien=brief["AnhDaiDien"],
                so_cup=brief["SoCupHienTai"],
                ten_hang=brief["TenHang"],
                is_ready=True,
            )
            self.rooms[ma_phong] = room
            self.user_room_map[host_id] = ma_phong

            return self._serialize_lobby(room)
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def _serialize_lobby(self, room: ActiveRoomRuntime) -> dict:
        players_list = []
        for p in room.players.values():
            players_list.append({
                "MaNguoiDung": p.user_id,
                "HoTen": p.ho_ten,
                "AnhDaiDien": p.anh_dai_dien,
                "SoCupHienTai": p.so_cup,
                "TenHang": p.ten_hang,
                "LaChuPhong": p.user_id == room.ma_chu_phong,
                "SanSang": p.is_ready,
            })

        can_start = len(room.players) >= 2 and all(p.is_ready for p in room.players.values())
        return {
            "MaPhong": room.ma_phong,
            "MaCodePhong": room.ma_code_phong,
            "LoaiPhong": room.loai_phong,
            "MaChuDe": room.ma_chu_de,
            "TenChuDe": room.ten_chu_de,
            "CoMatKhau": bool(room.mat_khau_phong),
            "MaChuPhong": room.ma_chu_phong,
            "TrangThai": room.status,
            "TongSoCau": len(room.questions),
            "DuDieuKienBatDau": can_start,
            "NguoiChoi": players_list,
        }




    async def invite_friend(self, host_id: int, target_user_id: int) -> dict:
        ma_phong = self.user_room_map.get(host_id)
        if not ma_phong or ma_phong not in self.rooms:
            raise ValueError("Bạn chưa ở trong phòng chờ nào.")

        room = self.rooms[ma_phong]
        if room.status != "CHO_NGUOI_CHOI":
            raise ValueError("Trận đấu đã bắt đầu.")
        if target_user_id in room.players:
            raise ValueError("Người chơi đã ở trong phòng.")
        if room.loai_phong == "DOI_KHANG_1VS1" and len(room.players) >= 2:
            raise ValueError("Phòng đối kháng 1vs1 đã đủ 2 người.")

        db = SessionLocal()
        try:
            inserted = db.execute(
                text("""
                    INSERT INTO LoiMoiPhongDau (
                        MaPhong, MaNguoiDuocMoi, TrangThai, ThoiGianHetHan, NgayTao
                    )
                    OUTPUT INSERTED.MaLoiMoi, INSERTED.ThoiGianHetHan
                    VALUES (
                        :phong, :target, 'CHO_PHAN_HOI',
                        DATEADD(SECOND, 60, SYSUTCDATETIME()), SYSUTCDATETIME()
                    )
                """),
                {"phong": ma_phong, "target": target_user_id},
            ).mappings().first()
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

        host = room.players[host_id]
        payload = {
            "MaLoiMoi": inserted["MaLoiMoi"],
            "MaPhong": room.ma_phong,
            "MaCodePhong": room.ma_code_phong,
            "LoaiPhong": room.loai_phong,
            "TenChuDe": room.ten_chu_de,
            "TongSoCau": len(room.questions),
            "MatKhauPhong": room.mat_khau_phong,
            "NguoiMoi": {
                "MaNguoiDung": host_id,
                "HoTen": host.ho_ten,
                "AnhDaiDien": host.anh_dai_dien,
                "SoCupHienTai": host.so_cup,
                "TenHang": host.ten_hang,
            },
            "ThoiGianHetHan": inserted["ThoiGianHetHan"].isoformat(),
        }
        await self.send_personal(target_user_id, "ROOM_INVITE_RECEIVED", payload)
        return payload

    async def join_room(self, user_id: int, ma_phong: int, mat_khau: Optional[str] = None) -> dict:
        if user_id in self.user_room_map:
            raise ValueError("Bạn đang ở trong một phòng đấu khác.")

        room = self.rooms.get(ma_phong)
        if not room or room.status != "CHO_NGUOI_CHOI":
            raise ValueError("Phòng đấu không tồn tại hoặc đã bắt đầu.")
        if user_id in room.kicked_users:
            raise ValueError("Bạn đã bị chủ phòng mời ra khỏi phòng này.")
        if room.loai_phong == "DOI_KHANG_1VS1" and len(room.players) >= 2:
            raise ValueError("Phòng đối kháng 1vs1 đã đủ 2 người.")
        if room.mat_khau_phong and room.mat_khau_phong != (mat_khau or "").strip():
            raise ValueError("Mật khẩu phòng không chính xác.")

        db = SessionLocal()
        try:
            brief = self._get_user_brief(db, user_id)
            mtv = db.execute(
                text("""
                    INSERT INTO ThanhVienPhongDau (
                        MaPhong, MaNguoiDung, TrangThai, SoCauDung, TongThoiGianTraLoiMs
                    )
                    OUTPUT INSERTED.MaThanhVienPhong
                    VALUES (:phong, :uid, 'SAN_SANG', 0, 0)
                """),
                {"phong": ma_phong, "uid": user_id},
            ).scalar()
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

        room.players[user_id] = PlayerRuntime(
            user_id=user_id,
            ma_thanh_vien_phong=mtv,
            ho_ten=brief["HoTen"],
            anh_dai_dien=brief["AnhDaiDien"],
            so_cup=brief["SoCupHienTai"],
            ten_hang=brief["TenHang"],
            is_ready=False,
        )
        self.user_room_map[user_id] = ma_phong

        lobby = self._serialize_lobby(room)
        await self.broadcast_room(room, "ROOM_LOBBY_UPDATED", lobby)
        return lobby

    async def toggle_ready(self, user_id: int, ready: bool):
        ma_phong = self.user_room_map.get(user_id)
        if not ma_phong or ma_phong not in self.rooms:
            return
        room = self.rooms[ma_phong]
        if room.status != "CHO_NGUOI_CHOI" or user_id == room.ma_chu_phong:
            return
        player = room.players.get(user_id)
        if player:
            player.is_ready = ready
            await self.broadcast_room(room, "ROOM_LOBBY_UPDATED", self._serialize_lobby(room))

    async def kick_player(self, host_id: int, target_user_id: int):
        ma_phong = self.user_room_map.get(host_id)
        if not ma_phong or ma_phong not in self.rooms:
            raise ValueError("Không tìm thấy phòng đấu.")
        room = self.rooms[ma_phong]
        if room.ma_chu_phong != host_id:
            raise ValueError("Chỉ chủ phòng mới có quyền đuổi người chơi.")
        if room.status != "CHO_NGUOI_CHOI":
            raise ValueError("Không thể đuổi khi trận đấu đã bắt đầu.")
        if target_user_id == host_id or target_user_id not in room.players:
            raise ValueError("Người chơi không hợp lệ.")

        room.players.pop(target_user_id, None)
        room.kicked_users.add(target_user_id)
        self.user_room_map.pop(target_user_id, None)

        db = SessionLocal()
        try:
            db.execute(
                text("DELETE FROM ThanhVienPhongDau WHERE MaPhong = :phong AND MaNguoiDung = :uid"),
                {"phong": ma_phong, "uid": target_user_id},
            )
            db.commit()
        finally:
            db.close()

        await self.send_personal(target_user_id, "KICKED_FROM_ROOM", {"MaPhong": ma_phong})
        await self.broadcast_room(room, "ROOM_LOBBY_UPDATED", self._serialize_lobby(room))




    def remove_from_duel_queue(self, user_id: int):
        for q_list in self.duel_queues.values():
            if user_id in q_list:
                q_list.remove(user_id)

    async def join_random_1vs1_queue(self, user_id: int, ma_chu_de: int):
        if user_id in self.user_room_map:
            await self.send_personal(user_id, "ERROR", {"message": "Bạn đang ở trong phòng đấu khác."})
            return


        db = SessionLocal()
        try:
            self._pick_topic_questions(db, ma_chu_de, QUESTIONS_COUNT_1VS1)
        except ValueError as e:
            await self.send_personal(user_id, "ERROR", {"message": str(e)})
            return
        finally:
            db.close()

        self.remove_from_duel_queue(user_id)
        queue = self.duel_queues.setdefault(ma_chu_de, [])
        queue.append(user_id)

        await self.send_personal(user_id, "SEARCHING_1VS1", {"MaChuDe": ma_chu_de})

        if len(queue) >= 2:
            p1_id = queue.pop(0)
            p2_id = queue.pop(0)
            try:
                lobby = await self.create_room(p1_id, "DOI_KHANG_1VS1", ma_chu_de, None)
                ma_phong = lobby["MaPhong"]
                await self.join_room(p2_id, ma_phong, None)
                room = self.rooms[ma_phong]
                room.che_do_ghep = "NGAU_NHIEN"
                room.players[p2_id].is_ready = True
                db = SessionLocal()
                try:
                    db.execute(
                        text("UPDATE PhongThiDau SET CheDoGhep = 'NGAU_NHIEN' WHERE MaPhong = :p"),
                        {"p": ma_phong},
                    )
                    db.commit()
                finally:
                    db.close()
                await self.start_room(p1_id)
            except Exception as e:
                await self.send_personal(p1_id, "ERROR", {"message": str(e)})
                await self.send_personal(p2_id, "ERROR", {"message": str(e)})




    async def start_room(self, host_id: int):
        ma_phong = self.user_room_map.get(host_id)
        if not ma_phong or ma_phong not in self.rooms:
            raise ValueError("Bạn không ở trong phòng nào.")

        room = self.rooms[ma_phong]
        if room.ma_chu_phong != host_id:
            raise ValueError("Chỉ chủ phòng mới được phép bắt đầu.")
        if room.status != "CHO_NGUOI_CHOI":
            raise ValueError("Trận đấu đã diễn ra rồi.")
        if len(room.players) < 2:
            raise ValueError("Cần tối thiểu 2 thí sinh để bắt đầu.")
        if not all(p.is_ready for p in room.players.values()):
            raise ValueError("Tất cả thí sinh trong phòng phải bấm Sẵn sàng trước khi bắt đầu.")

        room.status = "DANG_DIEN_RA"
        db = SessionLocal()
        try:
            db.execute(
                text("""
                    UPDATE PhongThiDau
                    SET TrangThai = 'DANG_DIEN_RA', ThoiGianBatDau = SYSUTCDATETIME()
                    WHERE MaPhong = :phong
                """),
                {"phong": ma_phong},
            )
            db.execute(
                text("UPDATE ThanhVienPhongDau SET TrangThai = 'DANG_THI' WHERE MaPhong = :phong"),
                {"phong": ma_phong},
            )
            db.commit()
        finally:
            db.close()


        await self.broadcast_room(
            room,
            "MATCH_COUNTDOWN",
            {
                "MaPhong": room.ma_phong,
                "LoaiPhong": room.loai_phong,
                "TenChuDe": room.ten_chu_de,
                "TongSoCau": len(room.questions),
                "CountdownSeconds": 5,
                "NguoiChoi": [
                    {
                        "MaNguoiDung": p.user_id,
                        "HoTen": p.ho_ten,
                        "AnhDaiDien": p.anh_dai_dien,
                        "SoCupHienTai": p.so_cup,
                        "TenHang": p.ten_hang,
                        "SoCauDung": 0,
                        "SoCauSai": 0,
                        "DaLam": 0,
                    }
                    for p in room.players.values()
                ],
            },
        )


        await asyncio.sleep(5)
        if room.status != "DANG_DIEN_RA":
            return

        if room.loai_phong == "DOI_KHANG_1VS1":
            await self._duel_send_shared_question(room)
        else:

            for p in room.players.values():
                if not p.left_or_forfeited:
                    await self._tournament_send_next_question(room, p)




    async def _duel_send_shared_question(self, room: ActiveRoomRuntime):
        if room.status != "DANG_DIEN_RA":
            return
        if room.shared_q_index >= len(room.questions):
            await self._finalize_room(room, is_cancelled=False)
            return

        for p in room.players.values():
            p.answered_current = False

        q = room.questions[room.shared_q_index]
        room.shared_q_started_at = time.monotonic()

        await self.broadcast_room(
            room,
            "NEW_QUESTION",
            {
                "Index": room.shared_q_index,
                "ThuTuCau": q["ThuTuCau"],
                "TongSoCau": len(room.questions),
                "MaCauHoi": q["MaCauHoi"],
                "NoiDung": q["NoiDung"],
                "HinhAnhUrl": q["HinhAnhUrl"],
                "MucDo": q["MucDo"],
                "ThoiGianGiay": q["ThoiGianGiay"],
                "ChoPhepNhieuDapAn": q["ChoPhepNhieuDapAn"],
                "DapAn": q["DapAn"],
            },
        )

        if room.shared_timer_task and not room.shared_timer_task.done():
            room.shared_timer_task.cancel()
        room.shared_timer_task = asyncio.create_task(
            self._duel_question_timeout(room, room.shared_q_index, q["ThoiGianGiay"])
        )

    async def _duel_question_timeout(self, room: ActiveRoomRuntime, expected_idx: int, timeout_sec: int):
        try:
            await asyncio.sleep(timeout_sec + 1)
            if room.status == "DANG_DIEN_RA" and room.shared_q_index == expected_idx:

                for p in room.players.values():
                    if not p.answered_current and not p.left_or_forfeited:
                        p.answered_current = True
                        p.answered_count += 1
                        p.wrong_count += 1
                        p.total_time_ms += timeout_sec * 1000
                await self._duel_advance_next(room)
        except asyncio.CancelledError:
            pass

    async def _duel_advance_next(self, room: ActiveRoomRuntime):
        if room.status != "DANG_DIEN_RA":
            return
        q = room.questions[room.shared_q_index]
        await self.broadcast_room(
            room,
            "QUESTION_ENDED",
            {
                "MaCauHoi": q["MaCauHoi"],
                "DanhSachMaDapAnDung": q["correct_ids"],
                "BangDiemHienTai": [
                    {
                        "MaNguoiDung": p.user_id,
                        "SoCauDung": p.correct_count,
                        "SoCauSai": p.wrong_count,
                        "DaLam": p.answered_count,
                    }
                    for p in room.players.values()
                ],
            },
        )
        room.shared_q_index += 1
        await asyncio.sleep(1.2)
        await self._duel_send_shared_question(room)




    async def _tournament_send_next_question(self, room: ActiveRoomRuntime, player: PlayerRuntime):
        if room.status != "DANG_DIEN_RA" or player.left_or_forfeited:
            return

        if player.personal_timer_task and not player.personal_timer_task.done():
            player.personal_timer_task.cancel()


        if player.current_q_index >= len(room.questions):
            player.finished = True
            db = SessionLocal()
            try:
                db.execute(
                    text("""
                        UPDATE ThanhVienPhongDau
                        SET TrangThai = 'HOAN_THANH',
                            SoCauDung = :dung,
                            TongThoiGianTraLoiMs = :ms
                        WHERE MaThanhVienPhong = :mtv
                    """),
                    {
                        "dung": player.correct_count,
                        "ms": player.total_time_ms,
                        "mtv": player.ma_thanh_vien_phong,
                    },
                )
                db.commit()
            finally:
                db.close()

            await self.send_personal(
                player.user_id,
                "PLAYER_COMPLETED_ALL",
                {
                    "MaPhong": room.ma_phong,
                    "SoCauDung": player.correct_count,
                    "SoCauSai": player.wrong_count,
                    "TongSoCau": len(room.questions),
                    "TongThoiGianTraLoiMs": player.total_time_ms,
                    "ChoPhepXemDapAn": False,
                    "ThongBao": "Bạn đã hoàn thành 50 câu! Đang chờ các thí sinh khác hoàn thành...",
                },
            )
            await self._broadcast_tournament_leaderboard(room)
            await self._check_tournament_all_done(room)
            return

        q = room.questions[player.current_q_index]
        player.question_started_at = time.monotonic()

        await self.send_personal(
            player.user_id,
            "NEW_QUESTION",
            {
                "Index": player.current_q_index,
                "ThuTuCau": q["ThuTuCau"],
                "TongSoCau": len(room.questions),
                "MaCauHoi": q["MaCauHoi"],
                "NoiDung": q["NoiDung"],
                "HinhAnhUrl": q["HinhAnhUrl"],
                "MucDo": q["MucDo"],
                "ThoiGianGiay": q["ThoiGianGiay"],
                "ChoPhepNhieuDapAn": q["ChoPhepNhieuDapAn"],
                "DapAn": q["DapAn"],
            },
        )

        player.personal_timer_task = asyncio.create_task(
            self._tournament_personal_timeout(room, player, player.current_q_index, q["ThoiGianGiay"])
        )

    async def _tournament_personal_timeout(
        self, room: ActiveRoomRuntime, player: PlayerRuntime, expected_idx: int, timeout_sec: int
    ):
        try:
            await asyncio.sleep(timeout_sec + 1)
            if (
                room.status == "DANG_DIEN_RA"
                and not player.left_or_forfeited
                and player.current_q_index == expected_idx
            ):

                player.answered_count += 1
                player.wrong_count += 1
                player.total_time_ms += timeout_sec * 1000
                player.current_q_index += 1
                await self._broadcast_tournament_leaderboard(room)
                await self._tournament_send_next_question(room, player)
        except asyncio.CancelledError:
            pass

    async def _broadcast_tournament_leaderboard(self, room: ActiveRoomRuntime):
        ranked = sorted(
            room.players.values(),
            key=lambda p: (p.left_or_forfeited, -p.correct_count, p.total_time_ms),
        )
        board = [
            {
                "ThuHangTamThoi": idx,
                "MaNguoiDung": p.user_id,
                "HoTen": p.ho_ten,
                "AnhDaiDien": p.anh_dai_dien,
                "SoCauDung": p.correct_count,
                "DaLam": p.answered_count,
                "TongSoCau": len(room.questions),
                "TongThoiGianTraLoiMs": p.total_time_ms,
                "DaXong": p.finished,
                "BoCuoc": p.left_or_forfeited,
            }
            for idx, p in enumerate(ranked, start=1)
        ]
        await self.broadcast_room(room, "TOURNAMENT_LIVE_BOARD", {"BangXepHang": board})

    async def _check_tournament_all_done(self, room: ActiveRoomRuntime):
        if room.status != "DANG_DIEN_RA":
            return
        if all(p.finished or p.left_or_forfeited for p in room.players.values()):
            await self._finalize_room(room, is_cancelled=False)




    async def handle_submit_answer(self, user_id: int, ma_cau_hoi: int, selected_ids: List[int]):
        ma_phong = self.user_room_map.get(user_id)
        if not ma_phong or ma_phong not in self.rooms:
            return
        room = self.rooms[ma_phong]
        if room.status != "DANG_DIEN_RA":
            return

        player = room.players.get(user_id)
        if not player or player.left_or_forfeited or player.finished:
            return


        if room.loai_phong == "DOI_KHANG_1VS1":
            if room.shared_q_index >= len(room.questions) or player.answered_current:
                return
            q = room.questions[room.shared_q_index]
            if q["MaCauHoi"] != ma_cau_hoi:
                return
            player.answered_current = True
            elapsed_ms = max(0, int((time.monotonic() - room.shared_q_started_at) * 1000))
        else:
            if player.current_q_index >= len(room.questions):
                return
            q = room.questions[player.current_q_index]
            if q["MaCauHoi"] != ma_cau_hoi:
                return
            if player.personal_timer_task and not player.personal_timer_task.done():
                player.personal_timer_task.cancel()
            elapsed_ms = max(0, int((time.monotonic() - player.question_started_at) * 1000))


        if elapsed_ms < 100:
            await self.handle_leave_or_forfeit(ma_phong, user_id, is_cheat=True, cheat_reason="Can thiệp thời gian trả lời")
            return

        unique_selected = set(selected_ids)
        correct_set = set(q["correct_ids"])
        is_correct = len(correct_set) > 0 and unique_selected == correct_set

        player.answered_count += 1
        player.total_time_ms += elapsed_ms
        if is_correct:
            player.correct_count += 1
        else:
            player.wrong_count += 1


        db = SessionLocal()
        try:
            for ans_id in unique_selected:
                db.execute(
                    text("""
                        INSERT INTO ChiTietTraLoiPhongDau (
                            MaThanhVienPhong, MaCauHoi, MaDapAn, ThoiGianPhanHoiMs
                        )
                        VALUES (:mtv, :ch, :da, :ms)
                    """),
                    {
                        "mtv": player.ma_thanh_vien_phong,
                        "ch": ma_cau_hoi,
                        "da": ans_id,
                        "ms": elapsed_ms,
                    },
                )
            db.commit()
        except Exception:
            db.rollback()
        finally:
            db.close()

        if room.loai_phong == "DOI_KHANG_1VS1":

            await self.send_personal(
                user_id,
                "ANSWER_RESULT",
                {
                    "MaCauHoi": ma_cau_hoi,
                    "LaCauDung": is_correct,
                    "DanhSachMaDapAnDung": q["correct_ids"],
                    "SoCauDung": player.correct_count,
                    "SoCauSai": player.wrong_count,
                },
            )

            await self.broadcast_room(
                room,
                "OPPONENT_SCORE_UPDATED",
                {
                    "MaNguoiDung": user_id,
                    "SoCauDung": player.correct_count,
                    "SoCauSai": player.wrong_count,
                    "DaChotCauHienTai": True,
                },
                exclude_user=user_id,
            )


            active_players = [p for p in room.players.values() if not p.left_or_forfeited]
            if len(active_players) == 2 and all(p.answered_current for p in active_players):
                if room.shared_timer_task and not room.shared_timer_task.done():
                    room.shared_timer_task.cancel()
                await self._duel_advance_next(room)
        else:

            await self.send_personal(
                user_id,
                "TOURNAMENT_ANSWER_RECORDED",
                {
                    "MaCauHoi": ma_cau_hoi,
                    "DaLam": player.answered_count,
                    "TongSoCau": len(room.questions),
                },
            )
            player.current_q_index += 1
            await self._broadcast_tournament_leaderboard(room)
            await self._tournament_send_next_question(room, player)




    async def handle_leave_or_forfeit(
        self,
        ma_phong: int,
        user_id: int,
        is_cheat: bool = False,
        cheat_reason: str = "Gian lận trong thi đấu",
    ):
        room = self.rooms.get(ma_phong)
        if not room:
            self.user_room_map.pop(user_id, None)
            return

        player = room.players.get(user_id)
        self.user_room_map.pop(user_id, None)


        if room.status == "CHO_NGUOI_CHOI":
            room.players.pop(user_id, None)
            db = SessionLocal()
            try:
                db.execute(
                    text("DELETE FROM ThanhVienPhongDau WHERE MaPhong = :phong AND MaNguoiDung = :uid"),
                    {"phong": ma_phong, "uid": user_id},
                )

                if user_id == room.ma_chu_phong or len(room.players) == 0:
                    room.status = "DA_HUY"
                    db.execute(
                        text("UPDATE PhongThiDau SET TrangThai = 'DA_HUY' WHERE MaPhong = :phong"),
                        {"phong": ma_phong},
                    )
                    db.commit()
                    for rem_uid in list(room.players.keys()):
                        self.user_room_map.pop(rem_uid, None)
                        await self.send_personal(rem_uid, "ROOM_CLOSED", {"message": "Chủ phòng đã giải tán phòng."})
                    self.rooms.pop(ma_phong, None)
                    return
                db.commit()
            finally:
                db.close()

            await self.broadcast_room(room, "ROOM_LOBBY_UPDATED", self._serialize_lobby(room))
            return


        if player:
            player.left_or_forfeited = True
            player.cheated = is_cheat
            if player.personal_timer_task and not player.personal_timer_task.done():
                player.personal_timer_task.cancel()

        db = SessionLocal()
        try:
            tv_status = "VI_PHAM" if is_cheat else "BO_CUOC"
            db.execute(
                text("""
                    UPDATE ThanhVienPhongDau
                    SET TrangThai = :st,
                        SoCauDung = :dung,
                        TongThoiGianTraLoiMs = :ms,
                        CupThayDoi = 0
                    WHERE MaPhong = :phong AND MaNguoiDung = :uid
                """),
                {
                    "st": tv_status,
                    "dung": player.correct_count if player else 0,
                    "ms": player.total_time_ms if player else 0,
                    "phong": ma_phong,
                    "uid": user_id,
                },
            )


            if is_cheat:
                db.execute(
                    text("""
                        UPDATE NguoiDung
                        SET TrangThaiTaiKhoan = 'BI_KHOA',
                            LyDoKhoa = :ly_do,
                            TrangThaiOnline = 0
                        WHERE MaNguoiDung = :uid
                    """),
                    {"ly_do": cheat_reason[:30], "uid": user_id},
                )
            db.commit()
        finally:
            db.close()

        if is_cheat:
            await self.send_personal(
                user_id,
                "ACCOUNT_LOCKED_CHEAT",
                {"message": "Phát hiện gian lận! Tài khoản của bạn đã bị khóa và hủy kết quả thi đấu."},
            )
            ws = self.active_connections.pop(user_id, None)
            if ws:
                try:
                    await ws.close(code=4008, reason="Tài khoản bị khóa do gian lận.")
                except Exception:
                    pass


        if room.loai_phong == "DOI_KHANG_1VS1" and room.status == "DANG_DIEN_RA":
            if room.shared_timer_task and not room.shared_timer_task.done():
                room.shared_timer_task.cancel()
            await self._finalize_room(room, is_cancelled=True, cancel_reason="Đối thủ đã rời trận hoặc vi phạm quy chế.")
            return


        if room.loai_phong == "GIAI_DAU_NN" and room.status == "DANG_DIEN_RA":
            await self._broadcast_tournament_leaderboard(room)
            remaining = [p for p in room.players.values() if not p.left_or_forfeited]
            if len(remaining) <= 1:
                await self._finalize_room(room, is_cancelled=True, cancel_reason="Các thí sinh khác đã rời phòng.")
            else:
                await self._check_tournament_all_done(room)




    async def _finalize_room(
        self,
        room: ActiveRoomRuntime,
        is_cancelled: bool = False,
        cancel_reason: str = "",
    ):
        if room.status in ("DA_KET_THUC", "DA_HUY"):
            return

        room.status = "DA_HUY" if is_cancelled else "DA_KET_THUC"
        total_questions = len(room.questions)
        min_required_answered = math.floor(total_questions * MIN_COMPLETION_RATIO) + 1

        ranked_players = sorted(
            room.players.values(),
            key=lambda p: (p.left_or_forfeited, -p.correct_count, p.total_time_ms),
        )

        db = SessionLocal()
        results_payload = []
        try:
            db.execute(
                text("""
                    UPDATE PhongThiDau
                    SET TrangThai = :st, ThoiGianKetThuc = SYSUTCDATETIME()
                    WHERE MaPhong = :phong
                """),
                {"st": room.status, "phong": room.ma_phong},
            )

            for rank_idx, p in enumerate(ranked_players, start=1):
                cup_delta = 0
                loai_bien_dong = "THANG_1VS1" if room.loai_phong == "DOI_KHANG_1VS1" else "GIAI_DAU_NN"
                ket_qua_label = "THUA"

                if p.cheated or p.left_or_forfeited:
                    cup_delta = 0
                    ket_qua_label = "VI_PHAM" if p.cheated else "BO_CUOC"
                elif is_cancelled:

                    ket_qua_label = "HUY_TRAN"
                    if p.answered_count >= min_required_answered:
                        cup_delta = CUP_1VS1_OPPONENT_LEFT
                else:

                    if room.loai_phong == "DOI_KHANG_1VS1":
                        if rank_idx == 1:
                            ket_qua_label = "THANG"
                            loai_bien_dong = "THANG_1VS1"
                            if p.answered_count >= min_required_answered:
                                cup_delta = CUP_1VS1_WIN
                        else:
                            ket_qua_label = "THUA"
                            loai_bien_dong = "THUA_1VS1"
                            if p.answered_count >= min_required_answered:
                                cup_delta = CUP_1VS1_LOSE
                    else:
                        ket_qua_label = f"TOP_{rank_idx}"
                        loai_bien_dong = "GIAI_DAU_NN"
                        if p.answered_count >= min_required_answered:
                            cup_delta = CUP_TOURNAMENT_TOP.get(rank_idx, CUP_TOURNAMENT_OTHER)

                cup_truoc = db.execute(
                    text("SELECT ISNULL(SoCupHienTai, 0) FROM NguoiDung WHERE MaNguoiDung = :uid"),
                    {"uid": p.user_id},
                ).scalar() or 0
                cup_sau = cup_truoc + cup_delta

                new_rank_id = db.execute(
                    text("""
                        SELECT TOP 1 MaHang
                        FROM CapBacHang
                        WHERE CupToiThieu <= :cup_sau
                        ORDER BY CupToiThieu DESC, ThuTuHang DESC
                    """),
                    {"cup_sau": cup_sau},
                ).scalar() or 1

                if cup_delta > 0:
                    db.execute(
                        text("""
                            UPDATE NguoiDung
                            SET SoCupHienTai = :cup_sau, MaHangHienTai = :ma_hang
                            WHERE MaNguoiDung = :uid
                        """),
                        {"cup_sau": cup_sau, "ma_hang": new_rank_id, "uid": p.user_id},
                    )
                    db.execute(
                        text("""
                            INSERT INTO LichSuBienDongCup (
                                MaNguoiDung, LoaiBienDong, MaThamChieu,
                                SoCupThayDoi, SoCupTruoc, SoCupSau, MoTa, NgayTao
                            )
                            VALUES (
                                :uid, :loai, :phong,
                                :delta, :truoc, :sau, :mota, SYSUTCDATETIME()
                            )
                        """),
                        {
                            "uid": p.user_id,
                            "loai": loai_bien_dong,
                            "phong": room.ma_phong,
                            "delta": cup_delta,
                            "truoc": cup_truoc,
                            "sau": cup_sau,
                            "mota": f"Phòng {room.ma_code_phong} ({ket_qua_label})",
                        },
                    )

                tv_final_status = (
                    "VI_PHAM"
                    if p.cheated
                    else ("BO_CUOC" if p.left_or_forfeited else "HOAN_THANH")
                )
                db.execute(
                    text("""
                        UPDATE ThanhVienPhongDau
                        SET TrangThai = :st,
                            SoCauDung = :dung,
                            TongThoiGianTraLoiMs = :ms,
                            ThuHang = :hang,
                            CupThayDoi = :delta
                        WHERE MaThanhVienPhong = :mtv
                    """),
                    {
                        "st": tv_final_status,
                        "dung": p.correct_count,
                        "ms": p.total_time_ms,
                        "hang": rank_idx,
                        "delta": cup_delta,
                        "mtv": p.ma_thanh_vien_phong,
                    },
                )

                results_payload.append({
                    "ThuHang": rank_idx,
                    "MaNguoiDung": p.user_id,
                    "HoTen": p.ho_ten,
                    "AnhDaiDien": p.anh_dai_dien,
                    "KetQua": ket_qua_label,
                    "SoCauDung": p.correct_count,
                    "SoCauSai": p.wrong_count,
                    "DaLam": p.answered_count,
                    "TongSoCau": total_questions,
                    "TongThoiGianTraLoiMs": p.total_time_ms,
                    "CupThayDoi": cup_delta,
                    "SoCupMoi": cup_sau,
                })

            db.commit()
        except Exception:
            db.rollback()
        finally:
            db.close()

        await self.broadcast_room(
            room,
            "MATCH_FINISHED",
            {
                "MaPhong": room.ma_phong,
                "LoaiPhong": room.loai_phong,
                "BiHuy": is_cancelled,
                "LyDoHuy": cancel_reason,
                "ChoPhepXemDapAn": True,
                "BangXepHang": results_payload,
            },
        )

        for uid in list(room.players.keys()):
            self.user_room_map.pop(uid, None)
        self.rooms.pop(room.ma_phong, None)


arena_manager = ArenaRealtimeManager()
