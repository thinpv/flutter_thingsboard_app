import 'package:flutter/material.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/gauge_tile.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/number_display.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/section_card.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/slider_tile.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/widgets/toggle_tile.dart';

/// Tự động build detail page từ [ProfileMetadata.states].
///
/// Các states được phân nhóm vào 3 section:
/// - **Điều khiển** — `controllable == true`
/// - **Trạng thái** — `!controllable && !chartable`
/// - **Biểu đồ** — `chartable == true` (Phase C: sẽ dùng RangeChart thật)
///
/// Escape hatch: đăng ký custom builder theo `uiType` hoặc `detailLayout`
/// trong [_customLayoutRegistry] để bypass auto-build cho các device đặc biệt
/// (camera, gateway…).
class DetailComposer {
  DetailComposer._();

  // ─── Custom layout registry ───────────────────────────────────────────────

  /// Escape hatch: `uiType` hoặc `detailLayout` → custom widget builder.
  ///
  /// Khai báo tại Phase C+ khi cần layout đặc biệt cho camera, gateway...
  /// Mặc định rỗng — auto-build áp dụng cho tất cả.
  ///
  /// Ví dụ đăng ký (trong main.dart hoặc app init):
  /// ```dart
  /// DetailComposer.register('camera', (ctx, meta, id) => CameraView(...));
  /// ```
  static final _customLayoutRegistry =
      <String, Widget Function(BuildContext, ProfileMetadata, String)>{};

  /// Đăng ký custom builder cho [uiTypeOrLayout].
  static void register(
    String uiTypeOrLayout,
    Widget Function(BuildContext, ProfileMetadata, String) builder,
  ) {
    _customLayoutRegistry[uiTypeOrLayout] = builder;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  /// Build detail widget từ [meta] cho [deviceId].
  ///
  /// Thứ tự ưu tiên:
  /// 1. `meta.uiHints.detailLayout` (nếu không phải 'auto') → custom registry
  /// 2. `meta.uiType` (nếu không phải 'auto') → custom registry
  /// 3. Auto-build từ `meta.states`
  static Widget build(
    BuildContext context,
    ProfileMetadata meta,
    String deviceId,
  ) {
    // 1. detailLayout override
    final detailLayout = meta.uiHints?.detailLayout;
    if (detailLayout != null && detailLayout != 'auto') {
      final custom = _customLayoutRegistry[detailLayout];
      if (custom != null) return custom(context, meta, deviceId);
    }

    // 2. uiType override
    if (meta.uiType != 'auto') {
      final custom = _customLayoutRegistry[meta.uiType];
      if (custom != null) return custom(context, meta, deviceId);
    }

    // 3. Auto-build
    return _AutoDetailPage(meta: meta, deviceId: deviceId);
  }

  // ─── Widget selector ──────────────────────────────────────────────────────

  /// Chọn widget phù hợp cho [key]/[def].
  ///
  /// Quy tắc:
  /// - bool + controllable → [ToggleTile]
  /// - bool + read-only → [ToggleTile] (onChanged null)
  /// - number + controllable + range → [SliderTile]
  /// - number + chartable → [NumberDisplay] (chart ở section riêng)
  /// - number + range (read-only) → [GaugeTile]
  /// - number → [NumberDisplay]
  /// - fallback → [NumberDisplay]
  static Widget widgetFor(String deviceId, String key, StateDef def) {
    switch (def.type) {
      case 'bool':
        return ToggleTile(deviceId: deviceId, stateKey: key, def: def);

      case 'number':
        if (def.controllable && def.range != null) {
          return SliderTile(deviceId: deviceId, stateKey: key, def: def);
        }
        if (def.range != null && !def.controllable) {
          return GaugeTile(deviceId: deviceId, stateKey: key, def: def);
        }
        return NumberDisplay(deviceId: deviceId, stateKey: key, def: def);

      default:
        return NumberDisplay(deviceId: deviceId, stateKey: key, def: def);
    }
  }
}

// ─── _AutoDetailPage ───────────────────────────────────────────���──────────────

class _AutoDetailPage extends StatelessWidget {
  const _AutoDetailPage({required this.meta, required this.deviceId});

  final ProfileMetadata meta;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];

    // Section 1: Điều khiển (controllable)
    final controls = meta.states.entries
        .where((e) => e.value.controllable)
        .map((e) => DetailComposer.widgetFor(deviceId, e.key, e.value))
        .toList();
    if (controls.isNotEmpty) {
      sections.add(SectionCard(title: 'Điều khiển', children: controls));
    }

    // Section 2: Trạng thái (!controllable && !chartable)
    final sensors = meta.states.entries
        .where((e) => !e.value.controllable && !e.value.chartable)
        .map((e) => DetailComposer.widgetFor(deviceId, e.key, e.value))
        .toList();
    if (sensors.isNotEmpty) {
      sections.add(SectionCard(title: 'Trạng thái', children: sensors));
    }

    // Section 3: Biểu đồ (chartable) — Phase B: NumberDisplay placeholder
    // Phase C: thay bằng RangeChart thật
    final chartables = meta.states.entries
        .where((e) => e.value.chartable)
        .map((e) => NumberDisplay(deviceId: deviceId, stateKey: e.key, def: e.value))
        .toList();
    if (chartables.isNotEmpty) {
      sections.add(SectionCard(title: 'Biểu đồ', children: chartables));
    }

    if (sections.isEmpty) {
      return _EmptyMetaView(deviceId: deviceId);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: sections,
    );
  }
}

// ─── Fallback khi states rỗng ─────────────────────────────────────────────────

class _EmptyMetaView extends StatelessWidget {
  const _EmptyMetaView({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Chưa có metadata cho thiết bị này',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
