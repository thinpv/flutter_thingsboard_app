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
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return SizedBox(
            height: 96,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [_AddSceneChip()],
            ),
          );
        }
        return SizedBox(
          height: 96,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              for (final scene in list) _SceneChip(scene: scene),
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
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onLongPress: () => _openEdit(context, ref),
        child: InkWell(
          onTap: () => _execute(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minWidth: 90, maxWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconData(scene.icon), color: accent, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  scene.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
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
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () => _openCreate(context, ref),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: Colors.grey.shade500, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Thêm',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
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
