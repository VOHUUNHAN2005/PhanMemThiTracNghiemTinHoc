import 'package:flutter/material.dart';

class AdminScrollableTable extends StatefulWidget {
  final Widget child;

  const AdminScrollableTable({super.key, required this.child});

  @override
  State createState() => _AdminScrollableTableState();
}

class _AdminScrollableTableState extends State {
  final ScrollController _horizontalCtrl = ScrollController();
  final ScrollController _verticalCtrl = ScrollController();

  @override
  void dispose() {
    _horizontalCtrl.dispose();
    _verticalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableChild = (widget as AdminScrollableTable).child;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _verticalCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalCtrl,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _horizontalCtrl,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: _horizontalCtrl,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: tableChild,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future showModernModal({
  required BuildContext context,
  required String title,
  String? subtitle,
  required IconData icon,
  Color accentColor = const Color(0xFF2563EB),
  double width = 520,
  required Widget Function(
          BuildContext ctx, void Function(void Function()) setModalState)
      bodyBuilder,
  required String confirmText,
  required Future Function() onConfirm,
}) async {
  bool isSubmitting = false;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          elevation: 16,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: width,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.04),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    border: const Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accentColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (subtitle != null && subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: bodyBuilder(ctx, setModalState),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          foregroundColor: const Color(0xFF475569),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(ctx, false),
                        child: const Text('Hủy bỏ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                final ok = await onConfirm();
                                if (ctx.mounted) {
                                  setModalState(() => isSubmitting = false);
                                  if (ok == true) Navigator.pop(ctx, true);
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(confirmText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future showModernConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? highlightText,
  String confirmText = 'Xác nhận xóa',
  Color accentColor = const Color(0xFFDC2626),
  IconData icon = Icons.delete_forever_rounded,
}) async {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF475569), height: 1.5),
            ),
            if (highlightText != null && highlightText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  highlightText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      foregroundColor: const Color(0xFF475569),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy bỏ',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirmText,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

InputDecoration modernInputDecoration({
  required String label,
  String? hint,
  IconData? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 20, color: const Color(0xFF64748B))
        : null,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
  );
}

Widget modernDropdownField({
  required dynamic value,
  required String label,
  required IconData prefixIcon,
  required List items,
  required void Function(dynamic) onChanged,
}) {
  return DropdownButtonFormField(
    value: value,
    isExpanded: true,
    icon:
        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
    dropdownColor: Colors.white,
    borderRadius: BorderRadius.circular(14),
    menuMaxHeight: 320,
    elevation: 4,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFF0F172A),
    ),
    decoration: modernInputDecoration(
      label: label,
      prefixIcon: prefixIcon,
    ),
    items: List.from(items),
    onChanged: onChanged,
  );
}

Widget modernFilterDropdown({
  required dynamic value,
  required String hint,
  required IconData icon,
  required List items,
  required void Function(dynamic) onChanged,
}) {
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFCBD5E1)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton(
        value: value,
        isExpanded: true,
        hint: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B), size: 20),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        menuMaxHeight: 320,
        elevation: 4,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0F172A),
        ),
        items: List.from(items),
        onChanged: onChanged,
      ),
    ),
  );
}

DropdownMenuItem buildModernDropdownItem({
  required dynamic value,
  required String text,
  IconData? icon,
  Color iconColor = const Color(0xFF2563EB),
}) {
  return DropdownMenuItem(
    value: value,
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    ),
  );
}
