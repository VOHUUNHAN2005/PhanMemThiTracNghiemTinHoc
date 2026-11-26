import 'package:flutter/material.dart';

typedef JsonMap = Map<String, dynamic>;

class ArenaResultScreen extends StatelessWidget {
  final bool isTournament;
  final String tenChuDe;
  final int myUserId;
  final JsonMap matchResultData;

  const ArenaResultScreen({
    super.key,
    required this.isTournament,
    required this.tenChuDe,
    required this.myUserId,
    required this.matchResultData,
  });

  @override
  Widget build(BuildContext context) {
    final bool biHuy = matchResultData['BiHuy'] == true;
    final String lyDoHuy = (matchResultData['LyDoHuy'] ?? '').toString();
    final List rawBoard = (matchResultData['BangXepHang'] is List)
        ? List.from(matchResultData['BangXepHang'])
        : [];
    final List<JsonMap> leaderboard = [];
    for (final e in rawBoard) {
      if (e is Map) {
        leaderboard.add(JsonMap.from(e));
      }
    }

    JsonMap myEntry = leaderboard.isNotEmpty ? leaderboard.first : JsonMap();
    for (final row in leaderboard) {
      if (int.tryParse((row['MaNguoiDung'] ?? 0).toString()) == myUserId) {
        myEntry = row;
        break;
      }
    }

    final int thuHang =
        int.tryParse((myEntry['ThuHang'] ?? 1).toString()) ?? 1;
    final int soCauDung =
        int.tryParse((myEntry['SoCauDung'] ?? 0).toString()) ?? 0;
    final int tongSoCau = int.tryParse(
          (myEntry['TongSoCau'] ?? (isTournament ? 50 : 20)).toString(),
        ) ??
        (isTournament ? 50 : 20);
    final int tongTimeMs =
        int.tryParse((myEntry['TongThoiGianTraLoiMs'] ?? 0).toString()) ?? 0;
    final double tongTimeSec = tongTimeMs / 1000.0;
    final int cupThayDoi =
        int.tryParse((myEntry['CupThayDoi'] ?? 0).toString()) ?? 0;
    final int soCupMoi =
        int.tryParse((myEntry['SoCupMoi'] ?? 0).toString()) ?? 0;
    final String ketQuaLabel = (myEntry['KetQua'] ?? '').toString();

    final bool isWinner = !biHuy && thuHang == 1 && ketQuaLabel != 'BO_CUOC';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF2FF),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Center(
              child: SizedBox(
                width: 390,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isWinner
                              ? [
                                  const Color(0xFF172554),
                                  const Color(0xFF2563EB),
                                ]
                              : [
                                  const Color(0xFF334155),
                                  const Color(0xFF475569),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A)
                                .withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isWinner
                                  ? Icons.emoji_events_rounded
                                  : Icons.military_tech_rounded,
                              color: isWinner
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white70,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            biHuy
                                ? 'TRẬN ĐẤU ĐÃ KẾT THÚC'
                                : (isTournament
                                    ? 'HẠNG $thuHang CHUNG CUỘC'
                                    : (isWinner
                                        ? 'CHIẾN THẮNG!'
                                        : 'HOÀN THÀNH TRẬN ĐẤU')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            biHuy && lyDoHuy.isNotEmpty ? lyDoHuy : tenChuDe,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  color: Color(0xFF1E293B),
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '+$cupThayDoi Cúp',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tổng Cúp hiện tại: $soCupMoi Cúp',
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            label: 'Số câu đúng',
                            value: '$soCauDung/$tongSoCau',
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            label: 'Tổng thời gian',
                            value: '${tongTimeSec.toStringAsFixed(1)}s',
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            label: 'Thứ hạng',
                            value: '#$thuHang',
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bảng xếp hạng trận đấu',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...leaderboard.map((item) {
                            final int rank = int.tryParse(
                                  (item['ThuHang'] ?? 1).toString(),
                                ) ??
                                1;
                            final int uid = int.tryParse(
                                  (item['MaNguoiDung'] ?? 0).toString(),
                                ) ??
                                0;
                            final bool isMe = uid == myUserId;
                            final String hoTen =
                                (item['HoTen'] ?? 'Thí sinh').toString();
                            final int dung = int.tryParse(
                                  (item['SoCauDung'] ?? 0).toString(),
                                ) ??
                                0;
                            final int ms = int.tryParse(
                                  (item['TongThoiGianTraLoiMs'] ?? 0)
                                      .toString(),
                                ) ??
                                0;
                            final int cup = int.tryParse(
                                  (item['CupThayDoi'] ?? 0).toString(),
                                ) ??
                                0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: rank == 1
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: rank == 1
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFCBD5E1),
                                    child: Text(
                                      '$rank',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isMe ? '$hoTen (Bạn)' : hoTen,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        Text(
                                          'Đúng: $dung/$tongSoCau • ${(ms / 1000.0).toStringAsFixed(1)}s',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '+$cup Cúp',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'QUAY VỀ TRANG CHỦ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}