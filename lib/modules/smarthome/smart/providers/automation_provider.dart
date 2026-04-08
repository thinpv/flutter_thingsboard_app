import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/utils/services/smarthome/automation_service.dart';

/// All server-side automations for the selected home.
final serverRulesProvider = FutureProvider<List<AutomationRule>>((ref) {
  final home = ref.watch(selectedHomeProvider);
  final homeData = home.valueOrNull;
  if (homeData == null) return Future.value([]);
  return AutomationService().fetchServerRules(homeData.id);
});

/// Gateway rule_index for a given gateway device id.
final gatewayRuleIndexProvider =
    FutureProvider.family<List<RuleIndexEntry>, String>(
  (ref, gatewayId) => AutomationService().fetchGatewayRuleIndex(gatewayId),
);
