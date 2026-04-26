import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/data/home_data_cache.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

/// Cache-first stream of rooms in the currently selected home.
///
/// Yields the Hive-cached snapshot immediately, then fetches over HTTP and
/// yields the fresh result. Eliminates the ~1-1.5s wait users see on cold
/// start before the room selector populates.
final roomsProvider = StreamProvider<List<SmarthomeRoom>>((ref) async* {
  final home = ref.watch(selectedHomeProvider);
  final homeData = home.valueOrNull;
  if (homeData == null) {
    yield const [];
    return;
  }
  final cached = HomeDataCache.instance.getRooms(homeData.id);
  if (cached != null && cached.isNotEmpty) {
    yield cached;
  }
  final fresh = await HomeService().fetchRooms(homeData.id);
  await HomeDataCache.instance.saveRooms(homeData.id, fresh);
  yield fresh;
});

/// Currently selected room id; null = show all rooms.
final selectedRoomIdProvider = StateProvider<String?>((ref) => null);
