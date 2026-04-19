import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/notification_prefs/providers/notification_prefs_providers.dart';

/// Cho phép user tắt category notification không muốn nhận. Lưu local
/// (Hive) — mỗi thiết bị có preferences riêng. FCM foreground handler
/// đọc và bỏ qua notification thuộc category đã mute.
///
/// Spec: NOTIFICATION_SYSTEM.md Phase 5 + §6.6.
class NotificationPreferencesPage extends ConsumerWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MpColors.text),
        title: const Text(
          'Cài đặt thông báo',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: MpColors.text,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _Hint(
            text:
                'Tắt category để không nhận push notification cho loại đó. '
                'Cài đặt áp dụng cho thiết bị này.',
          ),
          const SizedBox(height: 14),
          const _SectionLabel('LOẠI THÔNG BÁO'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: MpColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                _PrefTile(
                  icon: Icons.warning_amber_rounded,
                  iconColor: MpColors.red,
                  title: 'Cảnh báo thiết bị',
                  subtitle:
                      'Cảnh báo từ cảm biến cửa, khói, nhiệt độ, alarm hệ thống',
                  enabled: prefs[NotifCategory.deviceAlert] ?? true,
                  onChanged: (v) =>
                      notifier.setEnabled(NotifCategory.deviceAlert, v),
                ),
                const _Sep(),
                _PrefTile(
                  icon: Icons.auto_awesome_outlined,
                  iconColor: MpColors.amber,
                  title: 'Tự động hóa',
                  subtitle:
                      'Push từ action "Thông báo" trong kịch bản & automation',
                  enabled: prefs[NotifCategory.automation] ?? true,
                  onChanged: (v) =>
                      notifier.setEnabled(NotifCategory.automation, v),
                ),
                const _Sep(),
                _PrefTile(
                  icon: Icons.campaign_outlined,
                  iconColor: MpColors.violet,
                  title: 'Thông báo hệ thống',
                  subtitle:
                      'Cập nhật firmware, bảo trì, thông báo từ admin',
                  enabled: prefs[NotifCategory.systemAnnouncement] ?? true,
                  onChanged: (v) => notifier.setEnabled(
                      NotifCategory.systemAnnouncement, v),
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MpColors.text3,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: MpColors.green,
          ),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 0.5, color: MpColors.border),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MpColors.blueSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: MpColors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: MpColors.text2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: MpColors.text3,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
