
import 'package:flutter/material.dart';
import 'package:user/core/services/favorite_review_service.dart';
import 'package:user/features/home/official_exam_screen.dart';

class FavoriteExamsScreen extends StatefulWidget {
  final VoidCallback? onOpenPracticeTab;

  const FavoriteExamsScreen({
    super.key,
    this.onOpenPracticeTab,
  });

  @override
  State<FavoriteExamsScreen> createState() => _FavoriteExamsScreenState();
}

class _FavoriteExamsScreenState extends State<FavoriteExamsScreen> {
  final FavoriteReviewService _service = FavoriteReviewService();

  bool _isLoading = true;
  int _totalFavorites = 0;

  List<Map<String, dynamic>> _topics = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final data = await _service.getMyFavoritesGroupedByTopic();

      final rawTopics = (data['topics'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _totalFavorites =
              (data['total_favorites'] as num?)?.toInt() ?? 0;

          _topics = rawTopics
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFavorite(int maBoDe) async {
    try {
      await _service.toggleFavoriteExam(maBoDe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã bỏ khỏi danh sách bộ đề yêu thích.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _loadFavorites();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openExam(Map<String, dynamic> exam) async {
    final String loaiBoDe = (exam['LoaiBoDe'] ?? '').toString();
    final int maBoDe = (exam['MaBoDe'] as num).toInt();

    if (loaiBoDe == 'THI_CHINH_THUC') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfficialExamScreen(initialExamId: maBoDe),
        ),
      );

      if (mounted) {
        _loadFavorites();
      }
    } else {
      if (widget.onOpenPracticeTab != null) {
        Navigator.pop(context);
        widget.onOpenPracticeTab!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hãy mở mục Ôn tập để làm bộ đề luyện tập này.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFavorites,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 390,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Bộ đề yêu thích',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFE11D48),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_totalFavorites đề',
                                style: const TextStyle(
                                  color: Color(0xFFBE123C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_topics.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE4E6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                color: Color(0xFFE11D48),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Chưa có bộ đề yêu thích nào',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Hãy nhấn biểu tượng trái tim ở các bộ đề để lưu nhanh theo từng chủ đề tại đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._topics.map((topic) {
                        final String tenChuDe =
                            (topic['TenChuDe'] ?? 'Chủ đề chung').toString();

                        final int count =
                            (topic['SoBoDeYeuThich'] as num?)?.toInt() ?? 0;

                        final List exams =
                            (topic['DanhSachBoDe'] as List?) ?? const [];

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.folder_special_rounded,
                                      color: Color(0xFF1D5CE5),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tenChuDe,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$count bộ đề',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              ...exams.map((rawExam) {
                                final exam =
                                    Map<String, dynamic>.from(rawExam as Map);

                                final int maBoDe =
                                    (exam['MaBoDe'] as num).toInt();

                                final String tieuDe =
                                    (exam['TieuDe'] ?? '').toString();

                                final String loai =
                                    (exam['LoaiBoDe'] ?? '').toString();

                                final bool isOfficial =
                                    loai == 'THI_CHINH_THUC';

                                final int soCau =
                                    ((exam['SoLuongCauHoi'] ?? 0) as num)
                                        .toInt();

                                final int? phut =
                                    (exam['ThoiGianLamBai'] as num?)?.toInt();

                                final bool daDat = exam['DaDat'] == true;

                                return InkWell(
                                  onTap: () => _openExam(exam),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isOfficial
                                                          ? const Color(
                                                              0xFFEDE9FE,
                                                            )
                                                          : const Color(
                                                              0xFFDBEAFE,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        8,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isOfficial
                                                          ? 'Thi chính thức'
                                                          : 'Ôn tập',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isOfficial
                                                            ? const Color(
                                                                0xFF6D28D9,
                                                              )
                                                            : const Color(
                                                                0xFF1D4ED8,
                                                              ),
                                                      ),
                                                    ),
                                                  ),

                                                  if (daDat) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: const Color(
                                                          0xFFD1FAE5,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: const Text(
                                                        'Đã đạt',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF065F46,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),

                                              const SizedBox(height: 6),

                                              Text(
                                                tieuDe,
                                                style: const TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),

                                              const SizedBox(height: 4),

                                              Text(
                                                phut != null && phut > 0
                                                    ? '$phut phút • $soCau câu'
                                                    : '$soCau câu • Tự do',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        IconButton(
                                          tooltip: 'Bỏ yêu thích',
                                          onPressed: () =>
                                              _removeFavorite(maBoDe),
                                          icon: const Icon(
                                            Icons.favorite_rounded,
                                            color: Color(0xFFE11D48),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
