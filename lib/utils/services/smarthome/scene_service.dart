import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/notification_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class SceneService {
  SceneService()
      : _client = getIt<ITbClientService>().client,
        _control = DeviceControlService();

  final ThingsboardClient _client;
  final DeviceControlService _control;

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

  /// Executes a scene's actions sequentially.
  /// [homeId] is required to resolve nested scene actions.
  Future<void> executeScene(SmarthomeScene scene, {String? homeId}) async {
    await _runActions(
      scene.actions,
      sceneName: scene.name,
      homeId: homeId,
      visited: {scene.id},
    );
  }

  Future<void> _runActions(
    List<Map<String, dynamic>> actions, {
    required String sceneName,
    String? homeId,
    Set<String> visited = const {},
  }) async {
    for (final action in actions) {
      switch (action['type'] as String?) {
        case 'device':
          final deviceId = action['deviceId'] as String?;
          final data = action['data'] as Map<String, dynamic>?;
          if (deviceId != null && data != null && data.isNotEmpty) {
            await _control.sendOneWayRpc(deviceId, 'setValue', data);
          }

        case 'notify':
          final msg = action['message'] as String?;
          if (msg != null && msg.isNotEmpty) {
            final title = (action['title'] as String?)?.isNotEmpty == true
                ? action['title'] as String
                : sceneName;
            getIt<NotificationService>().showLocalNotification(title, msg);
          }

        case 'scene':
          final sceneId = action['sceneId'] as String?;
          if (sceneId != null && !visited.contains(sceneId) && homeId != null) {
            try {
              final scenes = await fetchScenes(homeId);
              final target = scenes.firstWhere((s) => s.id == sceneId);
              await _runActions(
                target.actions,
                sceneName: target.name,
                homeId: homeId,
                visited: {...visited, sceneId},
              );
            } catch (_) {}
          }

        case 'delay':
          final seconds = (action['seconds'] as num?)?.toInt() ?? 0;
          if (seconds > 0 && seconds <= 300) {
            await Future.delayed(Duration(seconds: seconds));
          }
      }
    }
  }
}
