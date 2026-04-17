/// Mô tả một key telemetry/attribute của thiết bị — type, unit, controllable...
/// Dùng trong ProfileMetadata.states.
class StateDef {
  const StateDef({
    required this.type,
    this.unit,
    this.labelDefault,
    this.labelKey,
    this.icon,
    this.controllable = false,
    this.cumulative = false,
    this.chartable = false,
    this.range,
    this.precision,
    this.enumValues,
  });

  factory StateDef.fromJson(Map<String, dynamic> json) {
    return StateDef(
      type: json['type'] as String? ?? 'string',
      unit: json['unit'] as String?,
      labelDefault: json['labelDefault'] as String?,
      labelKey: json['labelKey'] as String?,
      icon: json['icon'] as String?,
      controllable: json['controllable'] as bool? ?? false,
      cumulative: json['cumulative'] as bool? ?? false,
      chartable: json['chartable'] as bool? ?? false,
      range: json['range'] != null
          ? StateRange.fromJson(json['range'] as Map<String, dynamic>)
          : null,
      precision: json['precision'] as int?,
      enumValues: (json['enumValues'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  /// 'bool' | 'number' | 'string' | 'enum'
  final String type;

  /// Đơn vị hiển thị: 'W', '°C', '%', 'kWh'...
  final String? unit;
  final String? labelDefault;

  /// i18n key cho label (override labelDefault khi có bản dịch).
  final String? labelKey;
  final String? icon;

  /// App có thể gửi lệnh điều khiển key này.
  final bool controllable;

  /// Key là tích luỹ theo thời gian (e.g. energy kWh).
  final bool cumulative;

  /// Vẽ được chart theo timeseries.
  final bool chartable;

  /// Min/max cho slider và progress bar.
  final StateRange? range;

  /// Số chữ số thập phân khi hiển thị.
  final int? precision;

  /// Danh sách giá trị hợp lệ cho type 'enum'.
  final List<String>? enumValues;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (unit != null) 'unit': unit,
        if (labelDefault != null) 'labelDefault': labelDefault,
        if (labelKey != null) 'labelKey': labelKey,
        if (icon != null) 'icon': icon,
        'controllable': controllable,
        'cumulative': cumulative,
        'chartable': chartable,
        if (range != null) 'range': range!.toJson(),
        if (precision != null) 'precision': precision,
        if (enumValues != null) 'enumValues': enumValues,
      };
}

/// Khoảng giá trị hợp lệ cho số.
class StateRange {
  const StateRange({required this.min, required this.max});

  factory StateRange.fromJson(Map<String, dynamic> json) {
    return StateRange(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  final double min;
  final double max;

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}
