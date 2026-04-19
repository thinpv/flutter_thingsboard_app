import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/scene.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/scene_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/scene_service.dart';

/// mPipe-style horizontal scene strip: circular icon (52×52) + label below.
class QuickScenesStrip extends ConsumerWidget {
  const QuickScenesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(scenesProvider);

    return scenes.when(
      loading: () => const SizedBox(
        height: 84,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MpColors.text3,
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kịch bản',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openCreate(context, ref),
                  child: const Text(
                    'Tạo mới',
                    style: TextStyle(fontSize: 12, color: MpColors.blue),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final scene in list) _SceneItem(scene: scene),
                _AddSceneItem(onTap: () => _openCreate(context, ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => const AutomationEditPage(isTapToRun: true)),
    );
    if (saved == true) ref.invalidate(scenesProvider);
  }
}

// ─── Scene item: circle + label ───────────────────────────────────────────────

class _SceneItem extends ConsumerWidget {
  const _SceneItem({required this.scene});
  final SmarthomeScene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _parseColor(scene.color);
    final soft = color.withValues(alpha: 0.15);

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => _execute(context),
        onLongPress: () => _openEdit(context, ref),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: soft,
                ),
                child: Icon(_iconData(scene.icon), color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                scene.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MpColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
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
          SnackBar(
            content: Text('Đã kích hoạt: ${scene.name}'),
            backgroundColor: MpColors.green,
          ),
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
      MaterialPageRoute(
          builder: (_) =>
              AutomationEditPage(isTapToRun: true, scene: scene)),
    );
    if (saved == true) ref.invalidate(scenesProvider);
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

// ─── Add scene button ─────────────────────────────────────────────────────────

class _AddSceneItem extends StatelessWidget {
  const _AddSceneItem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MpColors.surface,
                border: Border.all(
                  color: MpColors.borderStrong,
                  width: 1,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: const Icon(Icons.add, size: 20, color: MpColors.text3),
            ),
            const SizedBox(height: 6),
            const Text(
              'Thêm',
              style: TextStyle(
                fontSize: 11,
                color: MpColors.text3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
