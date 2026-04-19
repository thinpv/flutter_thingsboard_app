import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

const _kDeliveryMethod = 'MOBILE_APP';

/// Latest 100 push notifications for the current user.
final notificationsProvider =
    FutureProvider.autoDispose<List<PushNotification>>((ref) async {
  final client = getIt<ITbClientService>().client;
  final query = PushNotificationQuery(
    TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC)),
  );
  final page = await client.getNotificationService().getNotifications(query);
  return page.data;
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
