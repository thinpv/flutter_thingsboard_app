import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

/// Self-contained shimmer effect — no third-party package.
/// Slides a soft highlight across the child every ~1.4s.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Slide gradient from -1.5 → 1.5 across the bounding box.
        final t = _ctrl.value * 3.0 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(t - 0.6, 0),
            end: Alignment(t + 0.6, 0),
            colors: const [
              MpColors.surfaceAlt,
              Color(0xFFE5E4DF),
              MpColors.surfaceAlt,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Single skeleton block — gray rounded rectangle.
class _Block extends StatelessWidget {
  const _Block({this.height, this.width, this.radius = 8});
  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton placeholder mirroring [DeviceCard] layout: square icon badge
/// top-left, two text lines stacked below, mini switch top-right.
class DeviceCardSkeleton extends StatelessWidget {
  const DeviceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MpColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MpColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Block(width: 42, height: 42, radius: 12),
                _Block(width: 36, height: 18, radius: 9),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(height: 13, width: 110, radius: 4),
                SizedBox(height: 6),
                _Block(height: 11, width: 70, radius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver grid of [count] skeleton cards laid out the same way as the real
/// device grid (2 columns, aspect 1.45). Drop in place of the real grid while
/// `loading`.
class DeviceGridSkeletonSliver extends StatelessWidget {
  const DeviceGridSkeletonSliver({this.count = 4, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => const DeviceCardSkeleton(),
          childCount: count,
        ),
      ),
    );
  }
}

/// Non-sliver grid wrapper for use inside `Center` / single-room view.
class DeviceGridSkeleton extends StatelessWidget {
  const DeviceGridSkeleton({this.count = 6, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
        ),
        itemCount: count,
        itemBuilder: (_, _) => const DeviceCardSkeleton(),
      ),
    );
  }
}

/// Horizontal strip of skeleton room chips, sized to match the real
/// [RoomSelector] (height 44).
class RoomSelectorSkeleton extends StatelessWidget {
  const RoomSelectorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: _Shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _Block(
            width: i == 0 ? 60 : 80,
            height: 28,
            radius: 14,
          ),
        ),
      ),
    );
  }
}
