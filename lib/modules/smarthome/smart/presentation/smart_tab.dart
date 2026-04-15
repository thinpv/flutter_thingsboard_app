import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/scene_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/smart/providers/automation_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/automation_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';

class SmartTab extends ConsumerStatefulWidget {
  const SmartTab({super.key});

  @override
  ConsumerState<SmartTab> createState() => _SmartTabState();
}

class _SmartTabState extends ConsumerState<SmartTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreatePickerSheet(
        onTapScene: () {
          Navigator.pop(context);
          _createScene(context);
        },
        onTapAutomation: () {
          Navigator.pop(context);
          _createAutomation(context);
        },
      ),
    );
  }

  Future<void> _createScene(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SceneEditPage()),
    );
    if (saved == true) ref.invalidate(scenesProvider);
  }

  Future<void> _createAutomation(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AutomationEditPage()),
    );
    if (saved == true) ref.invalidate(allRulesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(selectedHomeProvider).valueOrNull;
    final homeName = home?.name ?? 'Smart';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.home_outlined, size: 20),
            const SizedBox(width: 6),
            Text(
              homeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tạo mới',
            onPressed: () => _onAdd(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Chạm để Chạy'),
            Tab(text: 'Tự động hóa'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ScenesView(),
          _AutomationsView(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Scenes ────────────────────────────────────────────────────────────

class _ScenesView extends ConsumerWidget {
  const _ScenesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenesAsync = ref.watch(scenesProvider);

    return scenesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (scenes) {
        if (scenes.isEmpty) {
          return const _EmptyState(
            icon: Icons.touch_app_outlined,
            title: 'Chưa có kịch bản nào',
            subtitle: 'Nhấn + để tạo kịch bản đầu tiên',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: scenes.length,
          itemBuilder: (context, i) => _SceneGridCard(scene: scenes[i]),
        );
      },
    );
  }
}

class _SceneGridCard extends ConsumerWidget {
  const _SceneGridCard({required this.scene});

  final SmarthomeScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _parseColor(scene.color);

    return GestureDetector(
      onTap: () => _execute(context),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconData(scene.icon), color: Colors.white, size: 24),
                ),
                const Spacer(),
                Text(
                  scene.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // Menu button top-right
            Positioned(
              top: -8,
              right: -8,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: accent, size: 20),
                onSelected: (val) {
                  if (val == 'edit') _openEdit(context, ref);
                  if (val == 'delete') _confirmDelete(context, ref);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _execute(BuildContext context) async {
    try {
      await SceneService().executeScene(scene);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã kích hoạt: ${scene.name}')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kích hoạt kịch bản')),
        );
      }
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SceneEditPage(scene: scene)),
    );
    if (saved == true) ref.invalidate(scenesProvider);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa kịch bản'),
        content: Text('Xóa "${scene.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final home = ref.read(selectedHomeProvider).valueOrNull;
      if (home == null) return;
      await SceneService().deleteScene(home.id, scene.id);
      ref.invalidate(scenesProvider);
    }
  }

  Color _parseColor(String hex) {
    try {
      final value = int.parse(hex.replaceFirst('#', 'FF'), radix: 16);
      return Color(value);
    } catch (_) {
      return Colors.deepOrange;
    }
  }

  IconData _iconData(String name) {
    return switch (name) {
      'wb_sunny' => Icons.wb_sunny,
      'nights_stay' => Icons.nights_stay,
      'home' => Icons.home,
      'meeting_room' => Icons.meeting_room,
      'local_movies' => Icons.local_movies,
      'restaurant' => Icons.restaurant,
      'bedtime' => Icons.bedtime,
      'fitness_center' => Icons.fitness_center,
      _ => Icons.auto_awesome,
    };
  }
}

// ─── Tab 2: Automations ───────────────────────────────────────────────────────

class _AutomationsView extends ConsumerWidget {
  const _AutomationsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRules = ref.watch(allRulesProvider);

    return allRules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (rules) {
        if (rules.isEmpty) {
          return const _EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'Chưa có tự động hóa nào',
            subtitle: 'Nhấn + để tạo automation đầu tiên',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemCount: rules.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) => AutomationCard(rule: rules[i]),
        );
      },
    );
  }
}

// ─── Automation card ──────────────────────────────────────────────────────────

class AutomationCard extends ConsumerWidget {
  const AutomationCard({required this.rule, super.key});

  final AutomationRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _parseColor(rule.color);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          // For gateway rules created from rule_index (no conditions/actions),
          // fetch the full rule detail before opening the editor.
          var fullRule = rule;
          final et = rule.executionTarget;
          if (et != null &&
              et.startsWith('gw:') &&
              rule.conditions.isEmpty &&
              rule.actions.isEmpty) {
            final gwId = et.substring(3);
            final detail =
                await AutomationService().fetchGatewayRule(gwId, rule.id);
            if (detail != null) fullRule = detail;
          }
          if (!context.mounted) return;
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
                builder: (_) => AutomationEditPage(rule: fullRule)),
          );
          if (saved == true) ref.invalidate(allRulesProvider);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              // Icon avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconData(rule.icon), color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              // Name + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _Badge(
                          label: rule.isGatewayRule ? '⚡ Gateway' : '☁️ Server',
                          color: rule.isGatewayRule
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Toggle + chevron
              Switch.adaptive(
                value: rule.enabled,
                onChanged: (val) => _toggleEnabled(ref, val),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleEnabled(WidgetRef ref, bool enabled) async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    final svc = AutomationService();
    if (rule.isGatewayRule) {
      final gwId = rule.gatewayId!;
      final index = await svc.fetchGatewayRuleIndex(gwId);
      await svc.toggleGatewayRule(gwId, rule.id, enabled, index);
    } else {
      final rules = await svc.fetchServerRules(home.id);
      final updated = rules
          .map((r) => r.id == rule.id ? r.copyWith(enabled: enabled) : r)
          .toList();
      await svc.saveServerRules(home.id, updated);
    }
    ref.invalidate(allRulesProvider);
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

// ─── Create type picker sheet ─────────────────────────────────────────────────

class _CreatePickerSheet extends StatelessWidget {
  const _CreatePickerSheet({
    required this.onTapScene,
    required this.onTapAutomation,
  });

  final VoidCallback onTapScene;
  final VoidCallback onTapAutomation;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tạo mới',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _PickerTile(
              icon: Icons.touch_app,
              color: Colors.deepOrange,
              title: 'Chạm để Chạy',
              subtitle: 'Kịch bản chạy ngay khi bạn nhấn',
              onTap: onTapScene,
            ),
            const SizedBox(height: 10),
            _PickerTile(
              icon: Icons.auto_awesome,
              color: Colors.blue,
              title: 'Tự động hóa',
              subtitle: 'Chạy tự động theo điều kiện hoặc lịch trình',
              onTap: onTapAutomation,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
