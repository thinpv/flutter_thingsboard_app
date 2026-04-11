import 'dart:convert';

import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/action_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/automation_caps.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/ui_hints.dart';

/// Metadata của một DeviceProfile — đọc từ field `description` của
/// `DeviceProfileInfo` sau khi backend deploy patch A-S-2.
///
/// Spec đầy đủ: DEVICE_DESCRIPTOR_SYSTEM.md §4A.
class ProfileMetadata {
  const ProfileMetadata({
    this.v = 1,
    this.uiType = 'auto',
    this.icon,
    this.colorPrimary,
    this.states = const {},
    this.actions = const {},
    this.automation,
    this.uiHints,
    this.i18n,
  });

  /// Phiên bản schema. Hiện tại = 1.
  final int v;

  /// Widget type dùng để render detail page.
  /// Ví dụ: 'smart_plug' | 'light' | 'air_conditioner' | 'auto'
  final String uiType;

  /// Material icon name cho thiết bị.
  final String? icon;

  /// Màu chủ đạo (hex, ví dụ '#4CAF50').
  final String? colorPrimary;

  /// Mô tả từng key telemetry/attribute.
  final Map<String, StateDef> states;

  /// Metadata cho từng RPC method.
  final Map<String, ActionMetaDef> actions;

  /// Capabilities cho automation builder.
  final AutomationCaps? automation;

  /// Gợi ý bố cục UI.
  final UiHints? uiHints;

  /// Bản dịch theo locale: {'vi': {'name': '...'}, 'en': {...}}.
  final Map<String, Map<String, String>>? i18n;

  /// Trả về true nếu metadata này là rỗng (fallback, chưa có description từ backend).
  bool get isEmpty => states.isEmpty && uiType == 'auto' && icon == null;

  // ─── Factory ──────────────────────────────────────────────────────────────

  factory ProfileMetadata.fromJson(Map<String, dynamic> json) {
    return ProfileMetadata(
      v: json['v'] as int? ?? 1,
      uiType: json['ui_type'] as String? ?? 'auto',
      icon: json['icon'] as String?,
      colorPrimary: json['color_primary'] as String?,
      states: (json['states'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              StateDef.fromJson(v as Map<String, dynamic>),
            ),
          ) ??
          const {},
      actions: (json['actions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              ActionMetaDef.fromJson(v as Map<String, dynamic>),
            ),
          ) ??
          const {},
      automation: json['automation'] != null
          ? AutomationCaps.fromJson(json['automation'] as Map<String, dynamic>)
          : null,
      uiHints: json['ui_hints'] != null
          ? UiHints.fromJson(json['ui_hints'] as Map<String, dynamic>)
          : null,
      i18n: (json['i18n'] as Map<String, dynamic>?)?.map(
        (locale, translations) => MapEntry(
          locale,
          (translations as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v as String)),
        ),
      ),
    );
  }

  /// Parse từ `DeviceProfileInfo.description`.
  ///
  /// Tolerant: nếu [description] null, rỗng, hoặc không phải JSON hợp lệ →
  /// trả về `ProfileMetadata()` (empty). Logic cũ qua [device_profile_ui_service]
  /// vẫn hoạt động bình thường khi metadata empty.
  factory ProfileMetadata.tryParse(String? description) {
    if (description == null || description.isEmpty) {
      return const ProfileMetadata();
    }
    try {
      final decoded = jsonDecode(description);
      if (decoded is! Map<String, dynamic>) return const ProfileMetadata();
      return ProfileMetadata.fromJson(decoded);
    } catch (_) {
      return const ProfileMetadata();
    }
  }

  // ─── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'v': v,
        'ui_type': uiType,
        if (icon != null) 'icon': icon,
        if (colorPrimary != null) 'color_primary': colorPrimary,
        'states': states.map((k, v) => MapEntry(k, v.toJson())),
        'actions': actions.map((k, v) => MapEntry(k, v.toJson())),
        if (automation != null) 'automation': automation!.toJson(),
        if (uiHints != null) 'ui_hints': uiHints!.toJson(),
        if (i18n != null)
          'i18n': i18n!.map((locale, t) => MapEntry(locale, t)),
      };

  // ─── i18n helpers ─────────────────────────────────────────────────────────

  /// Tên thiết bị theo locale. Fallback: locale 'vi' → 'en' → null.
  String? localizedName(String locale) =>
      i18n?[locale]?['name'] ?? i18n?['vi']?['name'] ?? i18n?['en']?['name'];
}
