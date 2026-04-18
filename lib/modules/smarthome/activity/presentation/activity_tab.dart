import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  _Period _period = _Period.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hoạt động',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.01 * 22,
                        color: MpColors.text,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MpColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MpColors.border, width: 0.5),
                      ),
                      child: const Icon(
                        Icons.filter_list_rounded,
                        size: 16,
                        color: MpColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Hôm nay',
                    active: _period == _Period.today,
                    onTap: () => setState(() => _period = _Period.today),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '7 ngày',
                    active: _period == _Period.week,
                    onTap: () => setState(() => _period = _Period.week),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '30 ngày',
                    active: _period == _Period.month,
                    onTap: () => setState(() => _period = _Period.month),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: 'Tuỳ chỉnh',
                    active: _period == _Period.custom,
                    onTap: _pickCustomRange,
                  ),
                ],
              ),
            ),

            // ── Timeline ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: const [
                  _ActEvent(
                    time: '08:15',
                    dotColor: MpColors.green,
                    title: 'Kịch bản Buổi sáng đã chạy',
                    meta: '3 thiết bị thay đổi trạng thái',
                  ),
                  _ActEvent(
                    time: '08:14',
                    dotColor: MpColors.amber,
                    title: 'Đèn phòng ngủ tắt tự động',
                  ),
                  _ActEvent(
                    time: '07:42',
                    dotColor: MpColors.amber,
                    title: 'Cảm biến chuyển động phát hiện hoạt động tại cửa chính',
                  ),
                  _ActEvent(
                    time: '07:30',
                    dotColor: MpColors.amber,
                    title: 'Điều hòa tự bật',
                    meta: 'Nhiệt độ phòng vượt 28°C',
                  ),
                  _ActEvent(
                    time: '00:03',
                    dotColor: MpColors.red,
                    title: 'Camera cửa ghi lại chuyển động',
                    meta: 'Xem lại · 12 giây',
                    showThumb: true,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {}

  void _pickCustomRange() {}
}

enum _Period { today, week, month, custom }

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? MpColors.text : MpColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.transparent : MpColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? MpColors.bg : MpColors.text2,
          ),
        ),
      ),
    );
  }
}

// ─── Timeline event ───────────────────────────────────────────────────────────

class _ActEvent extends StatelessWidget {
  const _ActEvent({
    required this.time,
    required this.dotColor,
    required this.title,
    this.meta,
    this.showThumb = false,
    this.isLast = false,
  });

  final String time;
  final Color dotColor;
  final String title;
  final String? meta;
  final bool showThumb;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                time,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: MpColors.text3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Dot + connector line
          SizedBox(
            width: 10,
            child: Stack(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(color: MpColors.bg, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.2),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Positioned(
                    top: 18,
                    left: 4,
                    bottom: -20,
                    child: Container(
                      width: 1,
                      color: MpColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                    height: 1.35,
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (showThumb) ...[
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MpColors.border, width: 0.5),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: Color(0x80FFFFFF),
                          ),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          meta!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: MpColors.text3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
