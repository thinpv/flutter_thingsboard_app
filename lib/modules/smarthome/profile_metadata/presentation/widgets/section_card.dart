import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

/// Card chứa một nhóm tile (Điều khiển / Trạng thái / Biểu đồ).
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: MpColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MpColors.text3,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16,
              color: MpColors.border),
          ...children,
        ],
      ),
    );
  }
}

/// Placeholder hiển thị khi tile đang chờ dữ liệu lần đầu.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 12,
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile hiển thị khi có lỗi load dữ liệu.
class ErrorTile extends StatelessWidget {
  const ErrorTile(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: MpColors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Không đọc được dữ liệu',
              style: TextStyle(color: MpColors.text3, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
