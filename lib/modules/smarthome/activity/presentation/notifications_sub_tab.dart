import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/activity/providers/notifications_provider.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class NotificationsSubTab extends ConsumerStatefulWidget {
  const NotificationsSubTab({super.key});

  @override
  ConsumerState<NotificationsSubTab> createState() =>
      _NotificationsSubTabState();
}

class _NotificationsSubTabState extends ConsumerState<NotificationsSubTab>
    with AutomaticKeepAliveClientMixin {
  bool _unreadOnly = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notiAsync = ref.watch(notificationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _Chip(
                    label: 'Tất cả',
                    active: !_unreadOnly,
                    onTap: () => setState(() => _unreadOnly = false),
                  ),
                  const SizedBox(width: 6),
                  _Chip(
                    label: 'Chưa đọc',
                    active: _unreadOnly,
                    onTap: () => setState(() => _unreadOnly = true),
                  ),
                ],
              ),
              if (notiAsync.value?.isNotEmpty ?? false)
                GestureDetector(
                  onTap: () async {
                    await markAllNotificationsRead();
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationsCountProvider);
                  },
                  child: const Text(
                    'Đánh dấu đã đọc',
                    style: TextStyle(fontSize: 12, color: MpColors.blue),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: MpColors.text,
            backgroundColor: MpColors.surface,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (notiAsync.isLoading && !notiAsync.hasValue)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MpColors.text3,
                        strokeWidth: 1.5,
                      ),
                    ),
                  )
                else if (notiAsync.hasError)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: MpColors.text3, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Không thể tải thông báo',
                              style: TextStyle(
                                  color: MpColors.text,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${notiAsync.error}',
                              style: const TextStyle(
                                  color: MpColors.text3, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Vuốt xuống để thử lại',
                              style: TextStyle(
                                  color: MpColors.text3, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _buildList(notiAsync.value ?? const []),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<PushNotification> all) {
    final list = _unreadOnly
        ? all.where((n) => n.status == PushNotificationStatus.SENT).toList()
        : all;

    if (list.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none_outlined,
                  size: 40, color: MpColors.text3),
              const SizedBox(height: 12),
              Text(
                _unreadOnly
                    ? 'Không có thông báo chưa đọc'
                    : 'Không có thông báo nào',
                style: const TextStyle(
                    color: MpColors.text, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _NotificationCard(
          notification: list[i],
          onTap: () => _handleTap(list[i]),
          onDelete: () => _handleDelete(list[i]),
        ),
      ),
    );
  }

  Future<void> _handleTap(PushNotification n) async {
    if (n.status == PushNotificationStatus.SENT && n.id?.id != null) {
      await markNotificationRead(n.id!.id!);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }
    // TODO: deep-link based on n.additionalConfig / n.info
  }

  Future<void> _handleDelete(PushNotification n) async {
    if (n.id?.id == null) return;
    await deleteNotification(n.id!.id!);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }
}

// ─── Notification card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final PushNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unread = notification.status == PushNotificationStatus.SENT;
    final ts = notification.createdTime ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final iconData = _iconFor(notification);
    final iconColor = _iconColorFor(notification);

    return Dismissible(
      key: ValueKey(notification.id?.id ?? notification.hashCode),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: MpColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: MpColors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: unread ? MpColors.blueSoft : MpColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.15),
                  ),
                  child: Icon(iconData, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.subject,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: MpColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: MpColors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MpColors.text2,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _relativeTime(dt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: MpColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(PushNotification n) {
    return switch (n.type) {
      PushNotificationType.ALARM ||
      PushNotificationType.ALARM_ASSIGNMENT ||
      PushNotificationType.ALARM_COMMENT =>
        Icons.warning_amber_rounded,
      PushNotificationType.DEVICE_ACTIVITY => Icons.devices_other_outlined,
      PushNotificationType.NEW_PLATFORM_VERSION => Icons.system_update_alt,
      _ => Icons.notifications_outlined,
    };
  }

  Color _iconColorFor(PushNotification n) {
    return switch (n.type) {
      PushNotificationType.ALARM ||
      PushNotificationType.ALARM_ASSIGNMENT ||
      PushNotificationType.ALARM_COMMENT =>
        MpColors.red,
      PushNotificationType.DEVICE_ACTIVITY => MpColors.blue,
      PushNotificationType.NEW_PLATFORM_VERSION => MpColors.amber,
      _ => MpColors.text2,
    };
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
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
