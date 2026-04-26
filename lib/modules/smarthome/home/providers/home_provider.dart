import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/data/home_data_cache.dart';
import 'package:thingsboard_app/modules/smarthome/home/data/selected_home_prefs.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Cache-first stream of homes.
///
/// Yields the Hive-cached snapshot immediately (instant render on cold start
/// once data has been seen at least once), then fetches the network and yields
/// the fresh result. Watchers see [AsyncData] within milliseconds instead of
/// waiting ~1-2s for the HTTP roundtrip.
final homesProvider = StreamProvider<List<SmarthomeHome>>((ref) async* {
  final cached = HomeDataCache.instance.getHomes();
  if (cached != null && cached.isNotEmpty) {
    yield cached;
  }
  final fresh = await HomeService().fetchHomes();
  await HomeDataCache.instance.saveHomes(fresh);
  yield fresh;
});

/// Currently selected home id — initialised from Hive so it survives restarts.
/// [SelectedHomePrefs.init] must be called in main() before ProviderScope mounts.
final selectedHomeIdProvider = StateProvider<String?>(
  (ref) => SelectedHomePrefs.instance.getSelectedHomeId(),
);

/// Selected home, resolved from [homesProvider] + [selectedHomeIdProvider].
final selectedHomeProvider = Provider<AsyncValue<SmarthomeHome?>>((ref) {
  final homes = ref.watch(homesProvider);
  final selectedId = ref.watch(selectedHomeIdProvider);

  return homes.whenData((list) {
    if (list.isEmpty) return null;
    if (selectedId == null) return list.first;
    return list.firstWhere(
      (h) => h.id == selectedId,
      orElse: () => list.first,
    );
  });
});

/// Accent color of the selected home. null = use default theme colors.
final homeAccentColorProvider = Provider<Color?>((ref) {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  final hex = home?.accentColor;
  if (hex == null || hex.isEmpty) return null;
  try {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  } catch (_) {
    return null;
  }
});
