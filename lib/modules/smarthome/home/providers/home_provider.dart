import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_home.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Fetches all smarthome_home assets for the current customer.
final homesProvider = FutureProvider<List<SmarthomeHome>>((ref) {
  return HomeService().fetchHomes();
});

/// Currently selected home id (persists within session).
final selectedHomeIdProvider = StateProvider<String?>((ref) => null);

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
