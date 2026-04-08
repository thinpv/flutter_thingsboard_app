import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';

/// Scenes for the currently selected home.
final scenesProvider = FutureProvider<List<SmarthomeScene>>((ref) async {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  if (home == null) return [];
  return SceneService().fetchScenes(home.id);
});
