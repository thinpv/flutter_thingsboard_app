import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
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

final alarmsProvider = FutureProvider.autoDispose
    .family<List<AlarmInfo>, AlarmTimeRange>((ref, range) async {
  final client = getIt<ITbClientService>().client;
  final query = AlarmQueryV2(
    TimePageLink(
      100,
      0,
      null,
      SortOrder('createdTime', Direction.DESC),
      range.startTime,
      range.endTime,
    ),
  );
  final page = await client.getAlarmService().getAllAlarmsV2(query);
  return page.data;
});

/// Count of ACTIVE alarms not yet acknowledged — used for bottom-nav badge.
final activeUnackAlarmsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = getIt<ITbClientService>().client;
  final query = AlarmQueryV2(
    TimePageLink(100, 0, null, SortOrder('createdTime', Direction.DESC)),
    statusList: [AlarmSearchStatus.UNACK],
  );
  final page = await client.getAlarmService().getAllAlarmsV2(query);
  return page.data.where((a) => !a.cleared).length;
});
