import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

const _kDeliveryMethod = 'MOBILE_APP';

/// Latest 100 push notifications for the current user.
/// Fetch raw JSON để đọc info.details (PushNotificationInfo.fromJson drop field này),
/// inject details.icon / details.color vào additionalConfig trước khi parse model.
final notificationsProvider =
    FutureProvider.autoDispose<List<PushNotification>>((ref) async {
  final client = getIt<ITbClientService>().client;
  try {
    final queryParams = PushNotificationQuery(
      TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC)),
    ).toQueryParameters();

    final response = await client.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: queryParams,
    );

    final rawList =
        (response.data!['data'] as List).cast<Map<String, dynamic>>();

    return rawList.map(_parseWithDetails).toList();
  } catch (e, st) {
    debugPrint('[Notifications] ERROR: $e\n$st');
    rethrow;
  }
});

/// Parse một notification JSON, đồng thời inject icon/color từ info.details
/// vào additionalConfig.icon nếu có (override giá trị mặc định của template).
PushNotification _parseWithDetails(Map<String, dynamic> rawJson) {
  final details =
      (rawJson['info'] as Map?)?['details'] as Map<String, dynamic>?;

  if (details != null) {
    final iconName = details['details.icon']?.toString() ?? '';
    final colorStr = details['details.color']?.toString() ?? '';

    if (iconName.isNotEmpty || colorStr.isNotEmpty) {
      final ac = Map<String, dynamic>.from(
          (rawJson['additionalConfig'] as Map<String, dynamic>?) ?? {});
      final icon = Map<String, dynamic>.from((ac['icon'] as Map?) ?? {});
      if (iconName.isNotEmpty) icon['icon'] = iconName;
      if (colorStr.isNotEmpty) icon['color'] = colorStr;
      icon['enabled'] = true;
      ac['icon'] = icon;
      final patched = Map<String, dynamic>.from(rawJson);
      patched['additionalConfig'] = ac;
      return PushNotification.fromJson(patched);
    }
  }

  return PushNotification.fromJson(rawJson);
}

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
