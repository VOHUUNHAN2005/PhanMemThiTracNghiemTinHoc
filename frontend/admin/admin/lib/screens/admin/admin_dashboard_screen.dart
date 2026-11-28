import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_login_screen.dart';
import 'manage_users_screen.dart';
import 'manage_topics_screen.dart';
import 'manage_question_bank_screen.dart';
import 'manage_practice_screen.dart';
import 'manage_exams_screen.dart';
import 'manage_arena_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map adminProfile;

  const AdminDashboardScreen({
    super.key,
    required this.adminProfile,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ManageUsersScreen(),
    ManageTopicsScreen(),
    ManageQuestionBankScreen(),
    ManagePracticeScreen(),
    ManageExamsScreen(),
    ManageArenaScreen(),
  ];

  final List<String> _titles = const [
    'Quản lý Tài khoản & Phân quyền',
    'Quản lý Chủ đề Ôn tập',
    'Ngân hàng Câu hỏi & Định mức Độ khó',
    'Quản lý Bộ đề Ôn tập (Luyện tập)',
    'Quản lý Đề thi Chính thức',
    'Quản lý Đấu trường & Giải đấu',
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.adminProfile;
    final adminName = (profile['HoTen'] ?? 'Admin').toString();
    final adminEmail = (profile['Email'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            extended: MediaQuery.of(context).size.width >= 1150,
            backgroundColor: const Color(0xFF0F172A),
            unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedLabelTextStyle:
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            indicatorColor: const Color(0xFF2563EB),
            onDestinationSelected: (idx) =>
                setState(() => _selectedIndex = idx),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo_app.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (MediaQuery.of(context).size.width >= 1150) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'IT QUIZ ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt),
                label: Text('Tài khoản'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Chủ đề'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Ngân hàng câu hỏi'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: Text('Đề ôn tập'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('Đề thi chính thức'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: Text('Đấu trường & Giải đấu'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding:
                      const EdgeInsets.only(bottom: 20, left: 12, right: 12),
                  child: TextButton.icon(
                    onPressed: _logout,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF87171),
                      backgroundColor:
                          const Color(0xFFF87171).withOpacity(0.12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _titles[_selectedIndex],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            adminName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            adminEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFDBEAFE),
                        backgroundImage: AssetImage('assets/admin.png'),
                      )
                    ],
                  ),
                ),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}