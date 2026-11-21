class CupHistoryModel {
  final int maBienDong;
  final String loaiBienDong;
  final int? maThamChieu;
  final int soCupThayDoi;
  final int soCupTruoc;
  final int soCupSau;
  final String? moTa;
  final DateTime? ngayTao;

  CupHistoryModel({
    required this.maBienDong,
    required this.loaiBienDong,
    this.maThamChieu,
    required this.soCupThayDoi,
    required this.soCupTruoc,
    required this.soCupSau,
    this.moTa,
    this.ngayTao,
  });

  bool get isPositive => soCupThayDoi >= 0;

  String get formattedValue =>
      soCupThayDoi >= 0 ? '+$soCupThayDoi' : '$soCupThayDoi';

  String get displayTitle {
    if (moTa != null && moTa!.trim().isNotEmpty) return moTa!;
    switch (loaiBienDong) {
      case 'THI_CHINH_THUC_DAT':
        return 'Thi chính thức đạt';
      case 'THANG_1VS1':
        return 'Thắng 1vs1';
      case 'THUA_1VS1':
        return 'Thua 1vs1';
      case 'GIAI_DAU_NN':
        return 'Giải đấu nhiều người';
      case 'PHAT_GIAN_LAN':
        return 'Bị hủy kết quả / Phạt gian lận';
      case 'HOAN_PHAT':
        return 'Hoàn phạt cúp';
      case 'ADMIN_DIEU_CHINH':
        return 'Điều chỉnh từ hệ thống';
      default:
        return 'Biến động cúp';
    }
  }

  factory CupHistoryModel.fromJson(Map<String, dynamic> json) {
    return CupHistoryModel(
      maBienDong: json['MaBienDong'] ?? 0,
      loaiBienDong: json['LoaiBienDong'] ?? '',
      maThamChieu: json['MaThamChieu'],
      soCupThayDoi: json['SoCupThayDoi'] ?? 0,
      soCupTruoc: json['SoCupTruoc'] ?? 0,
      soCupSau: json['SoCupSau'] ?? 0,
      moTa: json['MoTa'],
      ngayTao: json['NgayTao'] != null
          ? DateTime.tryParse(json['NgayTao'].toString())
          : null,
    );
  }
}