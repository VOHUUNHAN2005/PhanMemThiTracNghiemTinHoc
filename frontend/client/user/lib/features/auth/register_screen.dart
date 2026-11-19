import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final hoTenCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final rePassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureRePass = true;

  static const String _baseUrl = 'http://10.0.2.2:8000';

  @override
  void dispose() {
    hoTenCtrl.dispose();
    userCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    rePassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final hoTen = hoTenCtrl.text.trim();
    final username = userCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final rePass = rePassCtrl.text;

    // 1. Validate cơ bản phía Client
    if (hoTen.isEmpty || username.isEmpty || email.isEmpty || pass.isEmpty) {
      _showSnackBar('Vui lòng điền đầy đủ thông tin.', Colors.red);
      return;
    }
    if (username.length < 3) {
      _showSnackBar('Username phải có ít nhất 3 ký tự.', Colors.red);
      return;
    }
    if (!email.contains('@')) {
      _showSnackBar('Định dạng Email không hợp lệ.', Colors.red);
      return;
    }
    if (pass.length < 6) {
      _showSnackBar('Mật khẩu phải có ít nhất 6 ký tự.', Colors.red);
      return;
    }
    if (pass != rePass) {
      _showSnackBar('Mật khẩu xác nhận không khớp.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    UserCredential? userCredential;

    try {
      // 2. Tạo tài khoản trên Firebase Auth
      userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final token = await userCredential.user?.getIdToken();
      if (token == null) {
        throw 'Không lấy được mã xác thực từ Firebase.';
      }

      // 3. Gọi API POST /api/users/register để lưu vào SQL Server
      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'TenDangNhap': username,
          'HoTen': hoTen,
          'AnhDaiDien': null,
        }),
      );

      if (response.statusCode != 201) {
        // Rollback: Xóa tài khoản vừa tạo trên Firebase nếu lưu DB thất bại (ví dụ: trùng TenDangNhap)
        await userCredential.user?.delete();
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        throw err['detail'] ?? 'Đăng ký thất bại (${response.statusCode}).';
      }

      // 4. Đăng xuất khỏi Firebase để người dùng đăng nhập lại từ màn Login
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      _showSnackBar('Đăng ký thành công! Vui lòng đăng nhập.', Colors.green);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Lỗi đăng ký: ${e.message}';
      if (e.code == 'email-already-in-use') {
        msg = 'Email này đã được sử dụng cho một tài khoản khác.';
      } else if (e.code == 'invalid-email') {
        msg = 'Địa chỉ email không hợp lệ.';
      } else if (e.code == 'weak-password') {
        msg = 'Mật khẩu quá yếu.';
      }
      _showSnackBar(msg, Colors.red);
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 360,
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tạo tài khoản', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.person_outline, size: 34, color: Color(0xFF1D5CE5)),
                ),
                const SizedBox(height: 6),
                const Text('Chọn ảnh đại diện (có thể bỏ qua)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 14),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: hoTenCtrl,
                          decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: userCtrl,
                          decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passCtrl,
                          obscureText: _obscurePass,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rePassCtrl,
                          obscureText: _obscureRePass,
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureRePass ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureRePass = !_obscureRePass),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D5CE5),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading ? null : _handleRegister,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đã có tài khoản? Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}