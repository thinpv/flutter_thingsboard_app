import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/utils/services/smarthome/automation_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';

/// All server-side automations for the selected home.
final serverRulesProvider = FutureProvider<List<AutomationRule>>((ref) {
  final home = ref.watch(selectedHomeProvider);
  final homeData = home.valueOrNull;
  if (homeData == null) return Future.value([]);
  return AutomationService().fetchServerRules(homeData.id);
});

/// Gateway device IDs for the selected home.
final gatewayDeviceIdsProvider = FutureProvider<List<String>>((ref) async {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  if (home == null) return [];
  final gws = await ProvisioningService().fetchGatewayDevices(home.id);
  return gws.map((d) => d.id).toList();
});

/// Gateway rule_index for a given gateway device id.
final gatewayRuleIndexProvider =
    FutureProvider.family<List<RuleIndexEntry>, String>(
  (ref, gatewayId) => AutomationService().fetchGatewayRuleIndex(gatewayId),
);

/// All rules (server + gateway) merged for the selected home.
final allRulesProvider = FutureProvider<List<AutomationRule>>((ref) async {
  final home = ref.watch(selectedHomeProvider).valueOrNull;
  if (home == null) return [];

  final svc = AutomationService();

  // Server rules
  final serverRules = await svc.fetchServerRules(home.id);

  // Gateway rules — from all gateway devices
  final gwIds = await ref.watch(gatewayDeviceIdsProvider.future);
  final gatewayRules = <AutomationRule>[];
  for (final gwId in gwIds) {
    final index = await svc.fetchGatewayRuleIndex(gwId);
    // Convert RuleIndexEntry → AutomationRule (lightweight, enough for list view)
    for (final entry in index) {
      gatewayRules.add(AutomationRule(
        id: entry.id,
        name: entry.name,
        icon: entry.icon,
        color: entry.color,
        enabled: entry.enabled,
        executionTarget: 'gw:$gwId',
      ));
    }
  }

  return [...serverRules, ...gatewayRules];
});
