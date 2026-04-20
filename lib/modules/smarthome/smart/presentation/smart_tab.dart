import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/smart/providers/automation_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/widgets/add_popup_button.dart';
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
      backgroundColor: Colors.transparent,
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
      MaterialPageRoute(
          builder: (_) => const AutomationEditPage(isTapToRun: true)),
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
    return Scaffold(
      backgroundColor: MpColors.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Container(
              color: MpColors.bg,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 20,
                right: 20,
                bottom: 0,
              ),
              child: Row(
                children: [
                  const Text(
                    'Smart',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                      color: MpColors.text,
                    ),
                  ),
                  const Spacer(),
                  const SmarthomeAddButton(),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: MpColors.text,
                indicatorWeight: 1.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: MpColors.text,
                unselectedLabelColor: MpColors.text3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Chạm để Chạy'),
                  Tab(text: 'Tự động hóa'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _ScenesView(),
            _AutomationsView(),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(_, __, ___) => Container(
        color: MpColors.bg,
        child: tabBar,
      );

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ─── Tab 1: Scenes ────────────────────────────────────────────────────────────

class _ScenesView extends ConsumerWidget {
  const _ScenesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenesAsync = ref.watch(scenesProvider);

    return RefreshIndicator(
      color: MpColors.text,
      backgroundColor: MpColors.surface,
      onRefresh: () async {
        ref.invalidate(scenesProvider);
        await ref.read(scenesProvider.future).catchError((_) => <dynamic>[]);
      },
      child: scenesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MpColors.text3, strokeWidth: 1.5),
        ),
        error: (e, _) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text('Lỗi: $e', style: const TextStyle(color: MpColors.text3)),
            ),
          ),
        ),
        data: (scenes) {
          if (scenes.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: const SizedBox(
                height: 400,
                child: _EmptyState(
                  icon: Icons.touch_app_outlined,
                  title: 'Chưa có kịch bản nào',
                  subtitle: 'Nhấn + để tạo kịch bản đầu tiên',
                ),
              ),
            );
          }
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: scenes.length,
            itemBuilder: (context, i) => _SceneGridCard(scene: scenes[i]),
          );
        },
      ),
    );
  }
}

class _SceneGridCard extends ConsumerWidget {
  const _SceneGridCard({required this.scene});
  final SmarthomeScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _parseColor(scene.color);
    final tint = Color.alphaBlend(accent.withValues(alpha: 0.08), MpColors.surface);

    return GestureDetector(
      onTap: () => _execute(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconData(scene.icon), color: Colors.white, size: 20),
                ),
                const Spacer(),
                Text(
                  scene.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: MpColors.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Positioned(
              top: -6,
              right: -6,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: MpColors.text3, size: 18),
                color: MpColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'edit') _openEdit(context, ref);
                  if (val == 'delete') _confirmDelete(context, ref);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa', style: TextStyle(color: MpColors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _execute(BuildContext context, WidgetRef ref) async {
    final accent = _parseColor(scene.color);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MpColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: MpColors.text3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconData(scene.icon), color: Colors.white, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                scene.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MpColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Xác nhận kích hoạt kịch bản này?',
                style: TextStyle(fontSize: 13, color: MpColors.text2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: MpColors.border),
                      ),
                      child: const Text('Hủy',
                          style: TextStyle(color: MpColors.text2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Thực hiện',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final home = ref.read(selectedHomeProvider).valueOrNull;
      await SceneService().executeScene(scene, homeId: home?.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MpColors.green,
            content: Text('Đã kích hoạt: ${scene.name}',
                style: const TextStyle(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
      MaterialPageRoute(
          builder: (_) =>
              AutomationEditPage(isTapToRun: true, scene: scene)),
    );
    if (saved == true) ref.invalidate(scenesProvider);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MpColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa kịch bản', style: TextStyle(color: MpColors.text)),
        content: Text('Xóa "${scene.name}"?',
            style: const TextStyle(color: MpColors.text2, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: MpColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: MpColors.red)),
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
      return MpColors.amber;
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

    return RefreshIndicator(
      color: MpColors.text,
      backgroundColor: MpColors.surface,
      onRefresh: () async {
        ref.invalidate(allRulesProvider);
        await ref.read(allRulesProvider.future).catchError((_) => <dynamic>[]);
      },
      child: allRules.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MpColors.text3, strokeWidth: 1.5),
        ),
        error: (e, _) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text('Lỗi: $e', style: const TextStyle(color: MpColors.text3)),
            ),
          ),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: const SizedBox(
                height: 400,
                child: _EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Chưa có tự động hóa nào',
                  subtitle: 'Nhấn + để tạo automation đầu tiên',
                ),
              ),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => AutomationCard(rule: rules[i]),
          );
        },
      ),
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
    final tint = Color.alphaBlend(accent.withValues(alpha: 0.1), MpColors.surface);

    return GestureDetector(
      onTap: () async {
        var fullRule = rule;
        final et = rule.executionTarget;
        if (et != null &&
            et.startsWith('gw:') &&
            rule.conditions.isEmpty &&
            rule.actions.isEmpty) {
          final gwId = et.substring(3);
          final indexEntry = RuleIndexEntry.fromRule(rule);
          final detail = await AutomationService().fetchGatewayRule(gwId, indexEntry);
          if (detail != null) fullRule = detail;
        }
        if (!context.mounted) return;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => AutomationEditPage(rule: fullRule)),
        );
        if (saved == true) ref.invalidate(allRulesProvider);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MpColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconData(rule.icon), color: accent, size: 20),
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
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: MpColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _ExecutionBadge(isGateway: rule.isGatewayRule),
                ],
              ),
            ),
            // Toggle
            _MpSwitch(
              value: rule.enabled,
              onChanged: (val) => _toggleEnabled(ref, val),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: MpColors.text3),
          ],
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
      return MpColors.blue;
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

class _ExecutionBadge extends StatelessWidget {
  const _ExecutionBadge({required this.isGateway});
  final bool isGateway;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isGateway ? MpColors.greenSoft : MpColors.blueSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGateway ? '⚡ Gateway' : '☁️ Server',
        style: TextStyle(
          fontSize: 11,
          color: isGateway ? MpColors.green : MpColors.blue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MpSwitch extends StatelessWidget {
  const _MpSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? MpColors.green : MpColors.border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
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
    return Container(
      decoration: const BoxDecoration(
        color: MpColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: MpColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Tạo mới',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MpColors.text,
              ),
            ),
          ),
          _PickerTile(
            icon: Icons.touch_app_outlined,
            iconTint: MpColors.amberSoft,
            iconColor: MpColors.amber,
            title: 'Chạm để Chạy',
            subtitle: 'Kịch bản chạy ngay khi bạn nhấn',
            onTap: onTapScene,
          ),
          _PickerTile(
            icon: Icons.auto_awesome_outlined,
            iconTint: MpColors.blueSoft,
            iconColor: MpColors.blue,
            title: 'Tự động hóa',
            subtitle: 'Chạy tự động theo điều kiện hoặc lịch trình',
            onTap: onTapAutomation,
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.iconTint,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconTint;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MpColors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: MpColors.text3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: MpColors.text3),
          ],
        ),
      ),
    );
  }
}

// ─── Shared empty state ───────────────────────────────────────────────────────

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
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: MpColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: MpColors.text3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: MpColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: MpColors.text3),
          ),
        ],
      ),
    );
  }
}
