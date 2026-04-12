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
          {_serverAttrKey: rules.map((r) => r.toJson()).toList()},
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
  Future<void> saveGatewayRule(
    String gatewayDeviceId,
    AutomationRule rule,
    List<RuleIndexEntry> currentIndex,
  ) async {
    final key = 'rule_${rule.id}';
    // Step 1: write full rule detail
    await _client.getAttributeService().saveEntityAttributesV2(
          DeviceId(gatewayDeviceId),
          'SHARED_SCOPE',
          {key: rule.toJson()},
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
}
