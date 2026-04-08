import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Fetches rooms for the currently selected home.
final roomsProvider = FutureProvider<List<SmarthomeRoom>>((ref) {
  final home = ref.watch(selectedHomeProvider);
  final homeData = home.valueOrNull;
  if (homeData == null) return Future.value([]);
  return HomeService().fetchRooms(homeData.id);
});

/// Currently selected room id; null = show all rooms.
final selectedRoomIdProvider = StateProvider<String?>((ref) => null);
