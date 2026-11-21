class UserModel {
  final int maNguoiDung;
  final String firebaseUid;
  final String tenDangNhap;
  final String email;
  final String hoTen;
  final String? anhDaiDien;
  final String vaiTro;
  final int soCupHienTai;
  final int maHangHienTai;
  final String tenHang;

  UserModel({
    required this.maNguoiDung,
    required this.firebaseUid,
    required this.tenDangNhap,
    required this.email,
    required this.hoTen,
    this.anhDaiDien,
    required this.vaiTro,
    required this.soCupHienTai,
    required this.maHangHienTai,
    required this.tenHang,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      maNguoiDung: json['MaNguoiDung'] ?? 0,
      firebaseUid: json['FirebaseUid'] ?? '',
      tenDangNhap: json['TenDangNhap'] ?? '',
      email: json['Email'] ?? '',
      hoTen: json['HoTen'] ?? 'Người dùng',
      anhDaiDien: json['AnhDaiDien'],
      vaiTro: json['VaiTro'] ?? 'THI_SINH',
      soCupHienTai: json['SoCupHienTai'] ?? 0,
      maHangHienTai: json['MaHangHienTai'] ?? 1,
      tenHang: json['TenHang'] ?? 'Đồng',
    );
  }
}