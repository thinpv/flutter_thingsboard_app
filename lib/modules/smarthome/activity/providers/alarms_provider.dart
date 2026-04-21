import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

enum AlarmPeriod { all, week, month }

final alarmsProvider = FutureProvider.autoDispose
    .family<List<AlarmInfo>, AlarmPeriod>((ref, period) async {
  final client = getIt<ITbClientService>().client;
  final now = DateTime.now();
  final int? startTime = switch (period) {
    AlarmPeriod.all   => null,
    AlarmPeriod.week  => now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
    AlarmPeriod.month => now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
  };
  // Không lọc theo status → trả cả ACTIVE lẫn CLEARED
  final query = AlarmQueryV2(
    TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC),
        startTime, now.millisecondsSinceEpoch),
  );
  final page = await client.getAlarmService().getAllAlarmsV2(query);
  return page.data;
});

/// Count of ACTIVE unacked alarms — used for bell badge.
final activeUnackAlarmsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = getIt<ITbClientService>().client;
  try {
    final query = AlarmQueryV2(
      TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC)),
      statusList: [AlarmSearchStatus.UNACK],
    );
    final page = await client.getAlarmService().getAllAlarmsV2(query);
    return page.data.where((a) => !a.cleared).length;
  } catch (_) {
    return 0;
  }
});
