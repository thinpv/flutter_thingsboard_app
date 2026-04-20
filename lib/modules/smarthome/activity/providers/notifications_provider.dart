import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

const _kDeliveryMethod = 'MOBILE_APP';

/// Latest 100 push notifications for the current user.
final notificationsProvider =
    FutureProvider.autoDispose<List<PushNotification>>((ref) async {
  debugPrint('[Notifications] Fetching...');
  final client = getIt<ITbClientService>().client;
  try {
    final query = PushNotificationQuery(
      TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC)),
    );
    final page = await client.getNotificationService().getNotifications(query);
    debugPrint('[Notifications] OK — count=${page.data.length}, '
        'unread=${page.data.where((n) => n.status == PushNotificationStatus.SENT).length}');
    return page.data;
  } catch (e, st) {
    debugPrint('[Notifications] ERROR: $e\n$st');
    rethrow;
  }
});

/// Unread count for bottom-nav badge.
final unreadNotificationsCountProvider =
    FutureProvider.autoDispose<int>((ref) {
  final client = getIt<ITbClientService>().client;
  return client
      .getNotificationService()
      .getUnreadNotificationsCount(_kDeliveryMethod);
});

Future<void> markNotificationRead(String id) async {
  final client = getIt<ITbClientService>().client;
  await client.getNotificationService().markNotificationAsRead(id);
}

Future<void> markAllNotificationsRead() async {
  final client = getIt<ITbClientService>().client;
  await client
      .getNotificationService()
      .markAllNotificationsAsRead(_kDeliveryMethod);
}

Future<void> deleteNotification(String id) async {
  final client = getIt<ITbClientService>().client;
  await client.getNotificationService().deleteNotification(id);
}

/// Notification chưa đọc thuộc category `system_announcement` (UC3 admin
/// broadcast). Identify qua `additionalConfig.category` hoặc rơi sang
/// `type == GENERAL` cho TB version chưa cấu hình category.
final systemAnnouncementsProvider =
    Provider.autoDispose<List<PushNotification>>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return list.where((n) {
    if (n.status != PushNotificationStatus.SENT) return false;
    final category = n.additionalConfig?['category'];
    if (category == 'system_announcement') return true;
    return category == null && n.type == PushNotificationType.GENERAL;
  }).toList();
});
