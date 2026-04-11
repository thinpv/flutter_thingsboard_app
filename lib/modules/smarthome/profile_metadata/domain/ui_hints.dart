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
  });

  factory UiHints.fromJson(Map<String, dynamic> json) {
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
    );
  }

  /// Key telemetry dùng cho toggle / trạng thái chính trên card.
  final String? primaryState;

  /// Keys telemetry hiển thị tóm tắt trên card (e.g. power, energy).
  final List<String> summaryStates;

  /// Layout preset cho device card: 'auto' | 'toggle_with_metrics' | 'sensor'...
  final String cardLayout;

  /// Layout preset cho detail page: 'auto' | 'tabbed'...
  final String detailLayout;

  /// Công suất tối đa (W) — dùng scale progress bar smart plug.
  final double? maxPower;

  /// Keys cần vẽ chart timeseries.
  final List<String> chartKeys;

  /// Quick action buttons trên card / detail.
  final List<QuickAction> quickActions;

  Map<String, dynamic> toJson() => {
        if (primaryState != null) 'primary_state': primaryState,
        'summary_states': summaryStates,
        'card_layout': cardLayout,
        'detail_layout': detailLayout,
        if (maxPower != null) 'max_power': maxPower,
        'chart_keys': chartKeys,
        'quick_actions': quickActions.map((a) => a.toJson()).toList(),
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
