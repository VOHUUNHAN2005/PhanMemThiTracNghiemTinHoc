import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user/core/constants/api_client.dart';
import 'package:user/core/constants/api_constants.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  final String logoAssetPath;
  final String appTitle;
  final Widget? homeScreen;

  const SplashScreen({
    super.key,
    this.logoAssetPath = 'assets/logo_app.png',
    this.appTitle = 'IT QUIZ APP',
    this.homeScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _primary = Color(0xFF1D5CE5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final minDelay = Future.delayed(const Duration(seconds: 1));
    Widget nextScreen = const LoginScreen();
    String? noticeMessage;

    try {
      final user = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 3), onTimeout: () => null);

      if (user != null && widget.homeScreen != null) {
        await user.getIdToken(true);
        final response = await ApiClient.get(ApiConstants.getMe)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          nextScreen = widget.homeScreen!;
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          try {
            final decoded = jsonDecode(utf8.decode(response.bodyBytes));
            if (decoded is Map && decoded['detail'] != null) {
              noticeMessage = decoded['detail'].toString();
            }
          } catch (_) {}
          await FirebaseAuth.instance.signOut();
        } else {
          noticeMessage = 'Không thể xác thực tài khoản. Vui lòng đăng nhập lại.';
        }
      }
    } on TimeoutException {
      noticeMessage = 'Kết nối máy chủ quá thời gian. Vui lòng thử lại.';
    } catch (_) {
      nextScreen = const LoginScreen();
    }

    await minDelay;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => nextScreen,
      ),
    );

    if (noticeMessage != null && noticeMessage.isNotEmpty) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(noticeMessage),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _decorativeCircle({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FBFF),
                  Color(0xFFEAF2FF),
                  Color(0xFFF5F8FF),
                ],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -80,
            child: _decorativeCircle(
              size: 260,
              color: _primary.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _decorativeCircle(
              size: 280,
              color: const Color(0xFF60A5FA).withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 172,
                      height: 172,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.12),
                            blurRadius: 35,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          widget.logoAssetPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      widget.appTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Khám phá kiến thức công nghệ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFDCE8FF),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: _primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'LEARN  •  PRACTICE  •  MASTER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SẴN SÀNG KHÁM PHÁ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}