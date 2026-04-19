import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class HomeStats {
  const HomeStats({
    this.temp,
    this.hum,
    this.totalPowerKw,
    this.fromWeather = false,
  });

  static const empty = HomeStats();

  final double? temp;
  final double? hum;
  final double? totalPowerKw;
  final bool fromWeather;
}

// ─── Weather API (Open-Meteo — free, no key needed) ──────────────────────────

class _WeatherData {
  const _WeatherData({required this.temp, required this.hum});
  final double temp;
  final double hum;
}

final _weatherProvider =
    FutureProvider.autoDispose.family<_WeatherData?, String>((ref, homeId) async {
  Map<String, dynamic>? location;
  try {
    location = await HomeService().fetchHomeLocation(homeId);
  } catch (_) {
    return null;
  }
  if (location == null) return null;
  final lat = _toDouble(location['lat']);
  final lng = _toDouble(location['lng']);
  if (lat == null || lng == null) return null;

  try {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lng'
      '&current=temperature_2m,relative_humidity_2m'
      '&forecast_days=1',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;
    final t = _toDouble(current['temperature_2m']);
    final h = _toDouble(current['relative_humidity_2m']);
    if (t == null || h == null) return null;
    return _WeatherData(temp: t, hum: h);
  } catch (_) {
    return null;
  }
});

// ─── Combined stats provider ──────────────────────────────────────────────────

/// Aggregates temp/hum/power from all devices in the selected home.
/// Falls back to Open-Meteo weather API when no sensor is available.
final homeStatsProvider = Provider.autoDispose<HomeStats>((ref) {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  if (home == null) return HomeStats.empty;

  final homeId = home.id;

  // Collect all devices: gateway-level + all rooms
  final homeDevices =
      ref.watch(devicesInHomeProvider(homeId)).valueOrNull ?? [];
  final rooms = ref.watch(roomsProvider).valueOrNull ?? [];
  final roomDevices = rooms
      .expand((r) =>
          ref.watch(devicesInRoomProvider(r.id)).valueOrNull ?? [])
      .toList();

  final allDevices = [...homeDevices, ...roomDevices];

  // Aggregate stats from device telemetry.
  // temp/hum: only from environmental sensors — smart plugs/lights run hot
  // and would report inaccurate ambient readings.
  const _envSensorTypes = {'temp_humidity', 'air_conditioner'};

  double? temp, hum;
  double totalPowerW = 0;

  for (final d in allDevices) {
    if (_envSensorTypes.contains(d.effectiveUiType)) {
      temp ??= _toDouble(d.telemetry['temp']);
      hum ??= _toDouble(d.telemetry['hum']);
    }
    final p = _toDouble(d.telemetry['power']);
    if (p != null) totalPowerW += p;
  }

  // If no sensor → use weather API
  bool fromWeather = false;
  if (temp == null || hum == null) {
    final weather = ref.watch(_weatherProvider(homeId));
    if (weather.hasValue && weather.value != null) {
      final w = weather.value!;
      temp ??= w.temp;
      hum ??= w.hum;
      fromWeather = true;
    }
  }

  return HomeStats(
    temp: temp,
    hum: hum,
    totalPowerKw: totalPowerW > 0 ? totalPowerW / 1000 : null,
    fromWeather: fromWeather,
  );
});

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
