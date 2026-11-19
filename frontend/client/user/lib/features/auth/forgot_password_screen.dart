import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  String thongBao = '';
  bool _isError = false;
  bool _isLoading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _isError = true;
        thongBao = 'Vui lòng nhập địa chỉ email hợp lệ.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      thongBao = '';
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() {
        _isError = false;
        thongBao = 'Đã gửi liên kết đặt lại mật khẩu tới $email. Vui lòng kiểm tra hộp thư (kể cả mục Spam).';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isError = true;
        if (e.code == 'user-not-found') {
          thongBao = 'Email này chưa được đăng ký trong hệ thống.';
        } else if (e.code == 'invalid-email') {
          thongBao = 'Định dạng email không hợp lệ.';
        } else {
          thongBao = 'Không thể gửi email (${e.message}).';
        }
      });
    } catch (e) {
      setState(() {
        _isError = true;
        thongBao = 'Đã xảy ra lỗi: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Quay lại'),
                ),
                const SizedBox(height: 16),
                const Text('Quên mật khẩu?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Text(
                  'Nhập email đã đăng ký, chúng tôi sẽ gửi liên kết để bạn đặt lại mật khẩu.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 28),
                const Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Nhập email đã đăng ký',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
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
                    onPressed: _isLoading ? null : _handleResetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Gửi liên kết đặt lại', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (thongBao.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      thongBao,
                      style: TextStyle(
                        color: _isError ? Colors.red : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Nhớ lại mật khẩu rồi? Đăng nhập'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}