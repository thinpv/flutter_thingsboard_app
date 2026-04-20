import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class SceneService {
  SceneService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  static const _scenesKey = 'scenes';

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  Future<List<SmarthomeScene>> fetchScenes(String homeId) async {
    final attrs = await _client.getAttributeService().getAttributesByScope(
          AssetId(homeId),
          'SERVER_SCOPE',
          [_scenesKey],
        );
    if (attrs.isEmpty) return [];
    final raw = attrs.first.getValue();
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) as List : raw as List;
    return list
        .map((e) => SmarthomeScene.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveScenes(String homeId, List<SmarthomeScene> scenes) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          AssetId(homeId),
          'SERVER_SCOPE',
          {_scenesKey: scenes.map((s) => s.toJson()).toList()},
        );
  }

  Future<void> saveScene(String homeId, SmarthomeScene scene) async {
    final current = await fetchScenes(homeId);
    final idx = current.indexWhere((s) => s.id == scene.id);
    final updated = [...current];
    if (idx >= 0) {
      updated[idx] = scene;
    } else {
      updated.add(scene);
    }
    await saveScenes(homeId, updated);
  }

  Future<void> deleteScene(String homeId, String sceneId) async {
    final current = await fetchScenes(homeId);
    final updated = current.where((s) => s.id != sceneId).toList();
    await saveScenes(homeId, updated);
  }

  // ─── Execute ─────────────────────────────────────────────────────────────────

  /// Triggers a scene via ThingsBoard cloud.
  /// TB Rule Chain (SmartHome Automation Engine) handles all actions
  /// including device control, delay, nested scenes, and push notifications.
  Future<void> executeScene(SmarthomeScene scene, {required String homeId}) async {
    await _client.getAttributeService().saveEntityTelemetry(
      AssetId(homeId),
      'ANY',
      {'runScene': {'sceneId': scene.id}},
    );
  }
}
