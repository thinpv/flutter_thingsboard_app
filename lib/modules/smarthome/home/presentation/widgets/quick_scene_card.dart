import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/scene_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';

/// Horizontal scroll strip of quick-run scene cards.
class QuickScenesStrip extends ConsumerWidget {
  const QuickScenesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(scenesProvider);

    return scenes.when(
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const SizedBox.shrink(),
      data: (list) {
        return SizedBox(
          height: 88,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              for (final scene in list)
                _SceneChip(scene: scene),
              _AddSceneChip(),
            ],
          ),
        );
      },
    );
  }
}

// ─── Individual scene chip ───────────────────────────────────────────────────

class _SceneChip extends ConsumerWidget {
  const _SceneChip({required this.scene});

  final SmarthomeScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _parseColor(scene.color);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: () => _openEdit(context, ref),
        child: InkWell(
          onTap: () => _execute(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 80,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconData(scene.icon), color: accent, size: 28),
                const SizedBox(height: 6),
                Text(
                  scene.name,
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
          const SnackBar(content: Text('Không thể kích hoạt scene')),
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

// ─── Add scene button chip ────────────────────────────────────────────────────

class _AddSceneChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _openCreate(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.grey.shade600, size: 28),
              const SizedBox(height: 6),
              Text(
                'Thêm',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SceneEditPage()),
    );
    if (saved == true) ref.invalidate(scenesProvider);
  }
}
