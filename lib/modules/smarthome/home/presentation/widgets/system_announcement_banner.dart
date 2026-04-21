import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/activity/presentation/activity_tab.dart';
import 'package:thingsboard_app/modules/smarthome/activity/providers/notifications_provider.dart';

/// Banner cho UC3 — admin broadcast (firmware update, bảo trì, khuyến mãi).
/// Hiển thị notification chưa đọc đầu tiên thuộc category
/// `system_announcement`. Tap → mở Activity tab. Nút đóng = mark as read.
///
/// Spec: NOTIFICATION_SYSTEM.md §6.4 + Phase 4.
class SystemAnnouncementBanner extends ConsumerWidget {
  const SystemAnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(systemAnnouncementsProvider);
    if (announcements.isEmpty) return const SizedBox.shrink();

    final n = announcements.first;
    final extra = announcements.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
                builder: (_) => const ActivityTab(initialTab: 0)),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: MpColors.violetSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: MpColors.violet,
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.subject,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MpColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        extra > 0
                            ? '${n.text}  ·  +$extra thông báo khác'
                            : n.text,
                        style: const TextStyle(
                          fontSize: 11,
                          color: MpColors.text2,
                          height: 1.35,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: MpColors.text3),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () async {
                    final id = n.id?.id;
                    if (id == null) return;
                    await markNotificationRead(id);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationsCountProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
