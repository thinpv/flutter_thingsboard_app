import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class AutomationService {
  AutomationService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  static const _serverAttrKey = 'automations';
  static const _ruleIndexKey = 'rule_index';

  /// Cache of TB device UUID → device name (the name used in
  /// v1/gateway/connect, e.g. MAC or Zigbee IEEE address).
  /// Populated on demand by [_resolveDeviceName].
  final Map<String, String> _deviceNameCache = {};

  // ─── Server rules (stored on Home Asset server_attr) ─────────────────────

  Future<List<AutomationRule>> fetchServerRules(String homeId) async {
    final attrs = await _client.getAttributeService().getAttributesByScope(
          AssetId(homeId),
          'SERVER_SCOPE',
          [_serverAttrKey],
        );
    if (attrs.isEmpty) return [];
    final raw = attrs.first.getValue();
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) as List : raw as List;
    return list
        .map((e) => AutomationRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveServerRules(
    String homeId,
    List<AutomationRule> rules,
  ) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          AssetId(homeId),
          'SERVER_SCOPE',
          {_serverAttrKey: rules.map((r) => r.toJson(includeEnabled: true)).toList()},
        );
  }

  // ─── Gateway rules (stored on Gateway Device shared_attr) ────────────────

  Future<List<RuleIndexEntry>> fetchGatewayRuleIndex(
    String gatewayDeviceId,
  ) async {
    final attrs = await _client.getAttributeService().getAttributesByScope(
          DeviceId(gatewayDeviceId),
          'SHARED_SCOPE',
          [_ruleIndexKey],
        );
    if (attrs.isEmpty) return [];
    final raw = attrs.first.getValue();
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) as List : raw as List;
    return list
        .map((e) => RuleIndexEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AutomationRule?> fetchGatewayRule(
    String gatewayDeviceId,
    String ruleId,
  ) async {
    final key = 'rule_$ruleId';
    final attrs = await _client.getAttributeService().getAttributesByScope(
          DeviceId(gatewayDeviceId),
          'SHARED_SCOPE',
          [key],
        );
    if (attrs.isEmpty) return null;
    final raw = attrs.first.getValue();
    if (raw == null) return null;
    final map = raw is String
        ? jsonDecode(raw) as Map<String, dynamic>
        : raw as Map<String, dynamic>;
    return AutomationRule.fromJson(map);
  }

  /// Write rule detail FIRST, then update the index.
  ///
  /// Before writing, translates every `device_id` (TB UUID) in conditions
  /// and actions to the device **name** that the gateway knows (the name
  /// registered via `v1/gateway/connect`). The gateway's DeviceManager is
  /// keyed by this name, not by TB UUIDs.
  Future<void> saveGatewayRule(
    String gatewayDeviceId,
    AutomationRule rule,
    List<RuleIndexEntry> currentIndex,
  ) async {
    final key = 'rule_${rule.id}';
    // Step 1: translate device_id → device name for gateway consumption
    final gwJson = await _toGatewayJson(rule);
    // Step 2: write full rule detail
    await _client.getAttributeService().saveEntityAttributesV2(
          DeviceId(gatewayDeviceId),
          'SHARED_SCOPE',
          {key: gwJson},
        );
    // Step 2: upsert index entry
    final entry = RuleIndexEntry.fromRule(rule);
    final idx = currentIndex.indexWhere((e) => e.id == rule.id);
    final newIndex = [...currentIndex];
    if (idx >= 0) {
      newIndex[idx] = entry;
    } else {
      newIndex.add(entry);
    }
    await saveGatewayRuleIndex(gatewayDeviceId, newIndex);
  }

  /// Toggle [enabled] on a gateway rule.
  ///
  /// Only updates `rule_index` — `enabled` is intentionally NOT stored in the
  /// rule body (`rule_{uuid}`).  The gateway reads `enabled` exclusively from
  /// `rule_index`; keeping it out of the body eliminates the two-write
  /// atomicity problem and `rule_index` becomes the single source of truth.
  Future<void> toggleGatewayRule(
    String gatewayDeviceId,
    String ruleId,
    bool enabled,
    List<RuleIndexEntry> currentIndex,
  ) async {
    final newIndex = currentIndex
        .map((e) => e.id == ruleId
            ? RuleIndexEntry(
                id: e.id,
                name: e.name,
                icon: e.icon,
                color: e.color,
                enabled: enabled,
                ts: e.ts,
                status: e.status,
              )
            : e)
        .toList();
    await saveGatewayRuleIndex(gatewayDeviceId, newIndex);
  }

  Future<void> deleteGatewayRule(
    String gatewayDeviceId,
    String ruleId,
    List<RuleIndexEntry> currentIndex,
  ) async {
    // Remove index entry first so gateway stops executing it
    final newIndex = currentIndex.where((e) => e.id != ruleId).toList();
    await saveGatewayRuleIndex(gatewayDeviceId, newIndex);
    // Delete the detail attribute
    await _client.getAttributeService().deleteEntityAttributes(
          DeviceId(gatewayDeviceId),
          'SHARED_SCOPE',
          ['rule_$ruleId'],
        );
  }

  Future<void> saveGatewayRuleIndex(
    String gatewayDeviceId,
    List<RuleIndexEntry> index,
  ) async {
    await _client.getAttributeService().saveEntityAttributesV2(
          DeviceId(gatewayDeviceId),
          'SHARED_SCOPE',
          {_ruleIndexKey: index.map((e) => e.toJson()).toList()},
        );
  }

  // ─── device_id → device name translation for gateway rules ────────────────

  Future<String> _resolveDeviceName(String tbDeviceId) async {
    final cached = _deviceNameCache[tbDeviceId];
    if (cached != null) return cached;
    final device = await _client.getDeviceService().getDevice(tbDeviceId);
    final name = device?.name ?? tbDeviceId;
    _deviceNameCache[tbDeviceId] = name;
    return name;
  }

  /// Produces a gateway-friendly copy of the rule JSON.
  /// Adds `device_name` (the name registered via v1/gateway/connect) next to
  /// each `device_id` (TB UUID) so the gateway can look up devices locally.
  /// Keeps `device_id` intact so the app can still read rules back for editing.
  Future<Map<String, dynamic>> _toGatewayJson(AutomationRule rule) async {
    final json = rule.toJson();

    final conditions = json['conditions'] as List<dynamic>? ?? [];
    for (final c in conditions) {
      if (c is Map<String, dynamic> &&
          c['type'] == 'device' &&
          c['device_id'] != null) {
        c['device_name'] =
            await _resolveDeviceName(c['device_id'] as String);
      }
    }

    final actions = json['actions'] as List<dynamic>? ?? [];
    for (final a in actions) {
      if (a is Map<String, dynamic> &&
          a['type'] == 'device' &&
          a['device_id'] != null) {
        a['device_name'] =
            await _resolveDeviceName(a['device_id'] as String);
      }
    }

    return json;
  }
}
