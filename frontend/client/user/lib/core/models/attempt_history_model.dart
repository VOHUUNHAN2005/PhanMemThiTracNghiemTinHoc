class AttemptHistoryModel {
  final int maLuotLam;
  final int maBoDe;
  final String tenBoDe;
  final String loaiBoDe; // 'THI_CHINH_THUC' | 'LUYEN_TAP'
  final String tenChuDe;
  final String trangThai;
  final DateTime? thoiGianBatDau;
  final DateTime? thoiGianNopBai;
  final int thoiGianLamGiay;
  final int soCauDung;
  final int tongSoCau;
  final double diemSo;
  final bool daDat;

  AttemptHistoryModel({
    required this.maLuotLam,
    required this.maBoDe,
    required this.tenBoDe,
    required this.loaiBoDe,
    required this.tenChuDe,
    required this.trangThai,
    this.thoiGianBatDau,
    this.thoiGianNopBai,
    required this.thoiGianLamGiay,
    required this.soCauDung,
    required this.tongSoCau,
    required this.diemSo,
    required this.daDat,
  });

  factory AttemptHistoryModel.fromJson(Map<String, dynamic> json) {
    return AttemptHistoryModel(
      maLuotLam: int.tryParse((json['MaLuotLam'] ?? 0).toString()) ?? 0,
      maBoDe: int.tryParse((json['MaBoDe'] ?? 0).toString()) ?? 0,
      tenBoDe: (json['TenBoDe'] ?? 'Bộ đề').toString(),
      loaiBoDe: (json['LoaiBoDe'] ?? 'LUYEN_TAP').toString(),
      tenChuDe: (json['TenChuDe'] ?? 'Chủ đề chung').toString(),
      trangThai: (json['TrangThai'] ?? '').toString(),
      thoiGianBatDau: json['ThoiGianBatDau'] != null
          ? DateTime.tryParse(json['ThoiGianBatDau'].toString())
          : null,
      thoiGianNopBai: json['ThoiGianNopBai'] != null
          ? DateTime.tryParse(json['ThoiGianNopBai'].toString())
          : null,
      thoiGianLamGiay:
          int.tryParse((json['ThoiGianLamGiay'] ?? 0).toString()) ?? 0,
      soCauDung: int.tryParse((json['SoCauDung'] ?? 0).toString()) ?? 0,
      tongSoCau: int.tryParse((json['TongSoCau'] ?? 0).toString()) ?? 0,
      diemSo: double.tryParse((json['DiemSo'] ?? 0).toString()) ?? 0.0,
      daDat: json['DaDat'] == true || json['DaDat'] == 1,
    );
  }
}

class AttemptAnswerOption {
  final int maDapAn;
  final String noiDung;
  final bool laDapAnDung;
  final bool nguoiDungChon;

  AttemptAnswerOption({
    required this.maDapAn,
    required this.noiDung,
    required this.laDapAnDung,
    required this.nguoiDungChon,
  });

  factory AttemptAnswerOption.fromJson(Map<String, dynamic> json) {
    return AttemptAnswerOption(
      maDapAn: int.tryParse((json['MaDapAn'] ?? 0).toString()) ?? 0,
      noiDung: (json['NoiDung'] ?? '').toString(),
      laDapAnDung: json['LaDapAnDung'] == true || json['LaDapAnDung'] == 1,
      nguoiDungChon:
          json['NguoiDungChon'] == true || json['NguoiDungChon'] == 1,
    );
  }
}

class AttemptQuestionReview {
  final int thuTuCau;
  final int maCauHoi;
  final String noiDung;
  final String? hinhAnhUrl;
  final String? giaiThich;
  final bool daTraLoi;
  final bool traLoiDung;
  final List<AttemptAnswerOption> dapAn;

  AttemptQuestionReview({
    required this.thuTuCau,
    required this.maCauHoi,
    required this.noiDung,
    this.hinhAnhUrl,
    this.giaiThich,
    required this.daTraLoi,
    required this.traLoiDung,
    required this.dapAn,
  });

  factory AttemptQuestionReview.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['DapAn'] as List?) ?? const [];
    return AttemptQuestionReview(
      thuTuCau: int.tryParse((json['ThuTuCau'] ?? 0).toString()) ?? 0,
      maCauHoi: int.tryParse((json['MaCauHoi'] ?? 0).toString()) ?? 0,
      noiDung: (json['NoiDung'] ?? '').toString(),
      hinhAnhUrl: (json['HinhAnhUrl'] ?? json['HinhAnh'])?.toString(),
      giaiThich: json['GiaiThich']?.toString(),
      daTraLoi: json['DaTraLoi'] == true || json['DaTraLoi'] == 1,
      traLoiDung: json['TraLoiDung'] == true || json['TraLoiDung'] == 1,
      dapAn: rawOptions
          .whereType()
          .map((e) => AttemptAnswerOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AttemptDetailModel {
  final int maLuotLam;
  final int maBoDe;
  final String tenBoDe;
  final String loaiBoDe;
  final String tenChuDe;
  final String trangThai;
  final int thoiGianLamGiay;
  final int soCauDung;
  final int tongSoCau;
  final double diemSo;
  final bool daDat;
  final List<AttemptQuestionReview> danhSachCauHoi;

  AttemptDetailModel({
    required this.maLuotLam,
    required this.maBoDe,
    required this.tenBoDe,
    required this.loaiBoDe,
    required this.tenChuDe,
    required this.trangThai,
    required this.thoiGianLamGiay,
    required this.soCauDung,
    required this.tongSoCau,
    required this.diemSo,
    required this.daDat,
    required this.danhSachCauHoi,
  });

  int get soCauChuaLam =>
      danhSachCauHoi.where((q) => !q.daTraLoi).length;

  int get soCauSai =>
      danhSachCauHoi.where((q) => q.daTraLoi && !q.traLoiDung).length;

  factory AttemptDetailModel.fromJson(Map<String, dynamic> json) {
    // Backend trả về {"attempt": {...}, "questions": [...]}
    final Map<String, dynamic> attemptMap = json['attempt'] is Map
        ? Map<String, dynamic>.from(json['attempt'] as Map)
        : json;

    final rawQuestions =
        (json['questions'] ?? json['DanhSachCauHoi'] ?? const []) as List;

    return AttemptDetailModel(
      maLuotLam: int.tryParse((attemptMap['MaLuotLam'] ?? 0).toString()) ?? 0,
      maBoDe: int.tryParse((attemptMap['MaBoDe'] ?? 0).toString()) ?? 0,
      tenBoDe: (attemptMap['TenBoDe'] ?? 'Chi tiết bài làm').toString(),
      loaiBoDe: (attemptMap['LoaiBoDe'] ?? 'LUYEN_TAP').toString(),
      tenChuDe: (attemptMap['TenChuDe'] ?? '').toString(),
      trangThai: (attemptMap['TrangThai'] ?? '').toString(),
      thoiGianLamGiay:
          int.tryParse((attemptMap['ThoiGianLamGiay'] ?? 0).toString()) ?? 0,
      soCauDung: int.tryParse((attemptMap['SoCauDung'] ?? 0).toString()) ?? 0,
      tongSoCau: int.tryParse((attemptMap['TongSoCau'] ?? 0).toString()) ?? 0,
      diemSo: double.tryParse((attemptMap['DiemSo'] ?? 0).toString()) ?? 0.0,
      daDat: attemptMap['DaDat'] == true || attemptMap['DaDat'] == 1,
      danhSachCauHoi: rawQuestions
          .whereType()
          .map(
            (e) => AttemptQuestionReview.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}