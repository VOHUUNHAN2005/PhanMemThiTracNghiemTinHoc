import 'package:flutter/material.dart';
import 'manage_users_screen.dart';
import 'manage_topics_screen.dart';
import 'manage_practice_screen.dart';
import 'manage_exams_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? adminProfile;
  const AdminDashboardScreen({super.key, this.adminProfile});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Quản lý Tài khoản',
    'Quản lý Chủ đề',
    'Quản lý Bộ đề ôn & Câu hỏi',
    'Quản lý Đề thi & Câu hỏi',
  ];

  final List<Widget> _pages = const [
    ManageUsersScreen(),
    ManageTopicsScreen(),
    ManagePracticeScreen(),
    ManageExamsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final adminName = widget.adminProfile?['HoTen'] ?? 'Quản trị viên';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // SIDEBAR BÊN TRÁI
          Container(
            width: 260,
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                const SizedBox(height: 28),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.terminal, color: Color.fromARGB(255, 255, 255, 255), size: 28),
                    SizedBox(width: 10),
                    Text(
                      'IT QUIZ ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildNavItem(0, Icons.people_outline, 'Quản lý Tài khoản'),
                _buildNavItem(1, Icons.category_outlined, 'Quản lý Chủ đề'),
                _buildNavItem(2, Icons.menu_book_outlined, 'Bộ đề ôn & Câu hỏi'),
                _buildNavItem(3, Icons.assignment_outlined, 'Đề thi & Câu hỏi'),
                const Spacer(),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    adminName,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text(
                    'Admin',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    tooltip: 'Đăng xuất',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // VÙNG NỘI DUNG CHÍNH
          Expanded(
            child: Column(
              children: [
                // Header trên cùng
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _titles[_selectedIndex],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Nội dung từng tab
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }
}