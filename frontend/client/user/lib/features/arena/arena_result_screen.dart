import 'package:flutter/material.dart';
import 'package:user/core/services/arena_service.dart';
import 'package:user/core/widgets/question_image_box.dart';

typedef JsonMap = Map<String, dynamic>;

class ArenaResultScreen extends StatelessWidget {
  final int maPhong;
  final bool isTournament;
  final String tenChuDe;
  final int myUserId;
  final JsonMap matchResultData;

  const ArenaResultScreen({
    super.key,
    required this.maPhong,
    required this.isTournament,
    required this.tenChuDe,
    required this.myUserId,
    required this.matchResultData,
  });

  void _showReviewBottomSheet(BuildContext context) {
    final int resolvedPhongId = maPhong > 0
        ? maPhong
        : (int.tryParse((matchResultData['MaPhong'] ?? 0).toString()) ?? 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chi tiết đáp án bài thi',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<JsonMap>(
                  future: ArenaService.getMatchReview(resolvedPhongId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            snapshot.error
                                .toString()
                                .replaceFirst('Exception: ', ''),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    final rawData = snapshot.data ?? {};
                    final dynamic rawList = rawData['DanhSachCauHoi'] ??
                        rawData['CauHoi'] ??
                        rawData['ChiTietCauHoi'] ??
                        rawData['ChiTiet'] ??
                        rawData['questions'] ??
                        rawData['data'];
                    final List questions =
                        rawList is List ? List.from(rawList) : [];

                    if (questions.isEmpty) {
                      return const Center(
                        child: Text('Không có dữ liệu chi tiết câu hỏi.'),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      itemCount: questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, index) {
                        final q = questions[index] is Map
                            ? JsonMap.from(questions[index])
                            : <String, dynamic>{};
                        final String noiDung = (q['NoiDung'] ??
                                q['NoiDungCauHoi'] ??
                                q['TenCauHoi'] ??
                                '')
                            .toString();

                        final dynamic rawOptions = q['DapAn'] ??
                            q['DanhSachDapAn'] ??
                            q['CacDapAn'] ??
                            q['LuaChon'];
                        final List options =
                            rawOptions is List ? List.from(rawOptions) : [];

                        final dynamic rawSelected =
                            q['DanhSachMaDapAnDaChon'] ??
                                q['DapAnDaChon'] ??
                                q['CacDapAnDaChon'];
                        final List selectedIdsRaw =
                            rawSelected is List ? List.from(rawSelected) : [];
                        final Set<int> selectedIds = selectedIdsRaw
                            .map((e) => int.tryParse(e.toString()) ?? 0)
                            .where((id) => id > 0)
                            .toSet();

                        final int singleChosenId = int.tryParse(
                              (q['MaDapAnDaChon'] ?? 0).toString(),
                            ) ??
                            0;
                        if (singleChosenId > 0) {
                          selectedIds.add(singleChosenId);
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Câu ${index + 1}: $noiDung',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              QuestionImageBox(
                                rawImageUrl: q['HinhAnhUrl'] ??
                                    q['HinhAnh'] ??
                                    q['hinh_anh_url'],
                                maxHeight: 180,
                              ),
                              const SizedBox(height: 10),
                              ...options.map((rawOpt) {
                                final opt = rawOpt is Map
                                    ? JsonMap.from(rawOpt)
                                    : <String, dynamic>{};
                                final int id = int.tryParse(
                                      (opt['MaDapAn'] ?? opt['id'] ?? 0)
                                          .toString(),
                                    ) ??
                                    0;
                                final String text = (opt['NoiDung'] ??
                                        opt['NoiDungDapAn'] ??
                                        '')
                                    .toString();
                                final bool isCorrect =
                                    opt['LaDapAnDung'] == true ||
                                        opt['LaDapAnDung'] == 1 ||
                                        opt['Dung'] == true;
                                final bool isChosen = opt['DaChon'] == true ||
                                    opt['DaChon'] == 1 ||
                                    opt['NguoiChoiChon'] == true ||
                                    (id > 0 && selectedIds.contains(id));

                                Color bg = Colors.white;
                                Color border = const Color(0xFFE2E8F0);
                                IconData? icon;
                                Color iconColor = Colors.grey;

                                if (isCorrect) {
                                  bg = const Color(0xFFDCFCE7);
                                  border = const Color(0xFF16A34A);
                                  icon = Icons.check_circle_rounded;
                                  iconColor = const Color(0xFF16A34A);
                                } else if (isChosen) {
                                  bg = const Color(0xFFFEE2E2);
                                  border = const Color(0xFFDC2626);
                                  icon = Icons.cancel_rounded;
                                  iconColor = const Color(0xFFDC2626);
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border),
                                  ),
                                  child: Row(
                                    children: [
                                      if (icon != null) ...[
                                        Icon(icon, size: 18, color: iconColor),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      if (isChosen)
                                        const Text(
                                          'Bạn chọn',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool biHuy = matchResultData['BiHuy'] == true;
    final bool choPhepXemDapAn = matchResultData['ChoPhepXemDapAn'] != false;
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
                    if (choPhepXemDapAn && !biHuy) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showReviewBottomSheet(context),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text(
                            'XEM LẠI CHI TIẾT ĐÁP ÁN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
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