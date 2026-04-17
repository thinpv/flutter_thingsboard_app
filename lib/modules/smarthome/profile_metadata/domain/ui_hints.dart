/// Config riêng cho điều hòa IR — đọc từ profile.ui_hints.ir_ac_config.
class IrAcConfig {
  const IrAcConfig({
    this.minTemp = 16,
    this.maxTemp = 30,
    this.defaultTemp = 25,
    this.modes = const ['cool', 'heat', 'fan', 'dry', 'auto'],
    this.fanSpeeds = const ['auto', 'low', 'mid', 'high'],
  });

  factory IrAcConfig.fromJson(Map<String, dynamic> json) => IrAcConfig(
        minTemp: (json['min_temp'] as num?)?.toInt() ?? 16,
        maxTemp: (json['max_temp'] as num?)?.toInt() ?? 30,
        defaultTemp: (json['default_temp'] as num?)?.toInt() ?? 25,
        modes: (json['modes'] as List<dynamic>?)?.map((e) => e as String).toList()
            ?? const ['cool', 'heat', 'fan', 'dry', 'auto'],
        fanSpeeds: (json['fan_speeds'] as List<dynamic>?)?.map((e) => e as String).toList()
            ?? const ['auto', 'low', 'mid', 'high'],
      );

  final int minTemp;
  final int maxTemp;
  final int defaultTemp;
  final List<String> modes;
  final List<String> fanSpeeds;

  Map<String, dynamic> toJson() => {
        'min_temp': minTemp,
        'max_temp': maxTemp,
        'default_temp': defaultTemp,
        'modes': modes,
        'fan_speeds': fanSpeeds,
      };
}

/// Gợi ý bố cục UI cho device card và detail page.
class UiHints {
  const UiHints({
    this.primaryState,
    this.summaryStates = const [],
    this.cardLayout = 'auto',
    this.detailLayout = 'auto',
    this.maxPower,
    this.chartKeys = const [],
    this.quickActions = const [],
    this.buttonLayout = const [],
    this.irAcConfig,
    this.capabilities = const [],
  });

  factory UiHints.fromJson(Map<String, dynamic> json) {
    final acRaw = json['ir_ac_config'];
    return UiHints(
      primaryState: json['primary_state'] as String?,
      summaryStates: (json['summary_states'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      cardLayout: json['card_layout'] as String? ?? 'auto',
      detailLayout: json['detail_layout'] as String? ?? 'auto',
      maxPower: (json['max_power'] as num?)?.toDouble(),
      chartKeys: (json['chart_keys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      quickActions: (json['quick_actions'] as List<dynamic>?)
              ?.map((e) => QuickAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      buttonLayout: (json['button_layout'] as List<dynamic>?) ?? const [],
      irAcConfig: acRaw != null
          ? IrAcConfig.fromJson(acRaw as Map<String, dynamic>)
          : null,
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Key telemetry dùng cho toggle / trạng thái chính trên card.
  final String? primaryState;

  /// Keys telemetry hiển thị tóm tắt trên card (e.g. power, energy).
  final List<String> summaryStates;

  /// Layout preset cho device card: 'auto' | 'toggle_with_metrics' | 'sensor'...
  final String cardLayout;

  /// Layout preset cho detail page:
  ///   'auto' | 'irRemote' | 'irAc' | 'rfSocket' | 'rfFan' | 'rfDoorbell'
  final String detailLayout;

  /// Công suất tối đa (W) — dùng scale progress bar smart plug.
  final double? maxPower;

  /// Keys cần vẽ chart timeseries.
  final List<String> chartKeys;

  /// Quick action buttons trên card / detail.
  final List<QuickAction> quickActions;

  /// Button layout cho IR/RF remote — đọc từ profile.ui_hints.button_layout
  /// HOẶC từ sub_binding_{devId} gateway client attr (ưu tiên sau).
  /// Shape: [{"action":"power","label":"Power","icon":"power_settings_new","row":0,"col":0}]
  final List<dynamic> buttonLayout;

  /// Config điều hòa — chỉ có khi detailLayout == 'irAc'.
  final IrAcConfig? irAcConfig;

  /// Danh sách tính năng gateway hỗ trợ: 'ir', 'rf', 'zigbee', 'ble', 'zwave'...
  /// Dùng để ẩn/hiện các nút thêm thiết bị trên GatewayView.
  final List<String> capabilities;

  Map<String, dynamic> toJson() => {
        if (primaryState != null) 'primary_state': primaryState,
        'summary_states': summaryStates,
        'card_layout': cardLayout,
        'detail_layout': detailLayout,
        if (maxPower != null) 'max_power': maxPower,
        'chart_keys': chartKeys,
        'quick_actions': quickActions.map((a) => a.toJson()).toList(),
        if (buttonLayout.isNotEmpty) 'button_layout': buttonLayout,
        if (irAcConfig != null) 'ir_ac_config': irAcConfig!.toJson(),
        if (capabilities.isNotEmpty) 'capabilities': capabilities,
      };
}

/// Một nút action nhanh hiển thị trên card hoặc detail page.
class QuickAction {
  const QuickAction({
    required this.method,
    required this.label,
    required this.icon,
  });

  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      method: json['method'] as String,
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? 'touch_app',
    );
  }

  final String method;
  final String label;
  final String icon;

  Map<String, dynamic> toJson() => {
        'method': method,
        'label': label,
        'icon': icon,
      };
}
