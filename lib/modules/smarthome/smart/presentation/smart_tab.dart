import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/smart/providers/automation_provider.dart';

class SmartTab extends ConsumerWidget {
  const SmartTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverRules = ref.watch(serverRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart'),
        elevation: 0,
      ),
      body: serverRules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Lỗi: $e')),
        data: (rules) {
          if (rules.isEmpty) return const _EmptyAutomationView();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rules.length,
            itemBuilder: (context, index) =>
                AutomationCard(rule: rules[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const AutomationEditPage(),
            ),
          );
          if (saved == true) ref.invalidate(serverRulesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo automation'),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyAutomationView extends StatelessWidget {
  const _EmptyAutomationView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Chưa có automation nào',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Nhấn + để tạo automation đầu tiên'),
        ],
      ),
    );
  }
}

// ─── Automation card ─────────────────────────────────────────────────────────

class AutomationCard extends ConsumerWidget {
  const AutomationCard({required this.rule, super.key});

  final AutomationRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _parseColor(rule.color);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(_iconData(rule.icon), color: accent),
        ),
        title: Text(rule.name),
        subtitle: Text(
          rule.isGatewayRule ? '⚡ Gateway local' : '☁️ Server',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: rule.enabled,
              onChanged: (val) => _toggleEnabled(ref, val),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AutomationEditPage(rule: rule),
            ),
          );
          if (saved == true) ref.invalidate(serverRulesProvider);
        },
      ),
    );
  }

  void _toggleEnabled(WidgetRef ref, bool enabled) {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    if (rule.isGatewayRule) {
      // TODO: gateway rule toggle via AutomationService
    } else {
      // TODO: server rule toggle via AutomationService
    }
  }

  Color _parseColor(String hex) {
    try {
      final value = int.parse(hex.replaceFirst('#', 'FF'), radix: 16);
      return Color(value);
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData _iconData(String name) {
    return switch (name) {
      'wb_sunny' => Icons.wb_sunny,
      'nights_stay' => Icons.nights_stay,
      'thermostat' => Icons.thermostat,
      'schedule' => Icons.schedule,
      'lightbulb' => Icons.lightbulb,
      'security' => Icons.security,
      _ => Icons.auto_awesome,
    };
  }
}
