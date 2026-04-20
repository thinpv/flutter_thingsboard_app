import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

enum AlarmPeriod { today, week, month }

class AlarmTimeRange {
  const AlarmTimeRange(this.startTime, this.endTime);
  final int startTime;
  final int endTime;

  @override
  bool operator ==(Object other) =>
      other is AlarmTimeRange &&
      other.startTime == startTime &&
      other.endTime == endTime;

  @override
  int get hashCode => Object.hash(startTime, endTime);
}

AlarmTimeRange alarmRangeForPeriod(AlarmPeriod period) {
  final now = DateTime.now();
  final end = now.millisecondsSinceEpoch;
  final start = switch (period) {
    AlarmPeriod.today =>
      DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
    AlarmPeriod.week =>
      now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
    AlarmPeriod.month =>
      now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
  };
  return AlarmTimeRange(start, end);
}

// GET /api/alarm/ASSET/{id} — accessible to CUSTOMER_USER.
final alarmsProvider = FutureProvider.autoDispose
    .family<List<AlarmInfo>, AlarmTimeRange>((ref, range) async {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  if (home == null) return [];
  final client = getIt<ITbClientService>().client;
  final query = AlarmQuery(
    TimePageLink(
      100,
      0,
      null,
      SortOrder('createdTime', Direction.DESC),
      range.startTime,
      range.endTime,
    ),
    affectedEntityId: AssetId(home.id),
  );
  final page = await client.getAlarmService().getAlarms(query);
  return page.data;
});

/// Count of ACTIVE unacked alarms — used for bottom-nav badge.
final activeUnackAlarmsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  if (home == null) return 0;
  final client = getIt<ITbClientService>().client;
  final query = AlarmQuery(
    TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC)),
    affectedEntityId: AssetId(home.id),
    searchStatus: AlarmSearchStatus.UNACK,
  );
  final page = await client.getAlarmService().getAlarms(query);
  return page.data.where((a) => !a.cleared).length;
});
