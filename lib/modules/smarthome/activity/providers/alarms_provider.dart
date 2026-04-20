import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

enum AlarmPeriod { all, week, month }

// GET /api/v2/alarms — dùng AlarmPeriod làm family key (stable enum, không re-fetch liên tục)
final alarmsProvider = FutureProvider.autoDispose
    .family<List<AlarmInfo>, AlarmPeriod>((ref, period) async {
  final client = getIt<ITbClientService>().client;

  // Tính time range bên trong provider, không đưa vào key
  final now = DateTime.now();
  final endTime = now.millisecondsSinceEpoch;
  final int? startTime = switch (period) {
    AlarmPeriod.all   => null,
    AlarmPeriod.week  => now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
    AlarmPeriod.month => now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
  };

  debugPrint('[Alarms] Fetching /api/v2/alarms | period=$period '
      'startTime=${startTime != null ? DateTime.fromMillisecondsSinceEpoch(startTime) : "none"}');

  try {
    final query = AlarmQueryV2(
      TimePageLink(
        100,
        0,
        null,
        SortOrder('createdTime', Direction.DESC),
        startTime,
        endTime,
      ),
      statusList: [AlarmSearchStatus.ACTIVE],
    );
    final page = await client.getAlarmService().getAllAlarmsV2(query);
    debugPrint('[Alarms] OK — count=${page.data.length}');
    return page.data;
  } catch (e, st) {
    debugPrint('[Alarms] ERROR: $e\n$st');
    rethrow;
  }
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
  } catch (e) {
    debugPrint('[Alarms] ERROR fetching unack count: $e');
    return 0;
  }
});
