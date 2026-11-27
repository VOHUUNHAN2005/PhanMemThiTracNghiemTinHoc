import 'package:flutter/material.dart';
import 'package:user/core/constants/app_colors.dart';

class BottomMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomMenu({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.home_outlined, 'title': 'Trang chủ'},
      {'icon': Icons.menu_book_outlined, 'title': 'Ôn tập'},
      {'icon': Icons.sports_martial_arts, 'title': 'Thi đấu'},
      {'icon': Icons.groups_outlined, 'title': 'Bạn bè'},
      {'icon': Icons.person_outline, 'title': 'Cá nhân'},
    ];

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (index) {
            final isSelected = selectedIndex == index;
            final color = isSelected ? AppColors.primaryBlue : AppColors.subText;

            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[index]['icon'] as IconData, size: 27, color: color),
                    const SizedBox(height: 3),
                    Text(
                      items[index]['title'] as String,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}