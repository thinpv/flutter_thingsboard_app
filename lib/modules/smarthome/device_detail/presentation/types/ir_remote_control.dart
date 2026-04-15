import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// IR Remote Control — điều khiển thiết bị IR (TV, quạt, điều hòa...) từ
// button_layout trong binding. Hiển thị grid nút bấm, gửi RPC khi nhấn.
//
// telemetry: trạng thái ảo (onoff0, volume, mode...) từ VirtualStateStore.
// actions:   map<actionName, {label, icon, color, row, col}> từ binding metadata.
// onRpc:     callback gửi method + params tới gateway.

// Metadata của một nút trên remote
class IrButtonMeta {
  const IrButtonMeta({
    required this.action,
    required this.label,
    required this.icon,
    this.color,
    required this.row,
    required this.col,
    this.params,
  });

  final String action;
  final String label;
  final IconData icon;
  final Color? color;
  final int row;
  final int col;
  // Params gửi kèm RPC (nếu có). Ví dụ: {"speed": "2"}
  final Map<String, dynamic>? params;

  factory IrButtonMeta.fromJson(Map<String, dynamic> json) {
    return IrButtonMeta(
      action: json['action'] as String? ?? 'unknown',
      label: json['label'] as String? ?? '',
      icon: _iconFromName(json['icon'] as String? ?? 'radio_button_unchecked'),
      color: json['color'] != null ? _colorFromHex(json['color'] as String) : null,
      row: (json['row'] as num?)?.toInt() ?? 0,
      col: (json['col'] as num?)?.toInt() ?? 0,
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  static IconData _iconFromName(String name) {
    const map = <String, IconData>{
      'power_settings_new': Icons.power_settings_new,
      'volume_up': Icons.volume_up,
      'volume_down': Icons.volume_down,
      'volume_off': Icons.volume_off,
      'arrow_upward': Icons.arrow_upward,
      'arrow_downward': Icons.arrow_downward,
      'arrow_back': Icons.arrow_back,
      'arrow_forward': Icons.arrow_forward,
      'check': Icons.check,
      'menu': Icons.menu,
      'home': Icons.home,
      'settings': Icons.settings,
      'thermostat': Icons.thermostat,
      'air': Icons.air,
      'speed': Icons.speed,
      'wb_sunny': Icons.wb_sunny,
      'ac_unit': Icons.ac_unit,
      'dry': Icons.dry,
      'cloudy_snowing': Icons.cloudy_snowing,
      'tv': Icons.tv,
      'input': Icons.input,
      'channel_plus': Icons.add_circle_outline,
      'channel_minus': Icons.remove_circle_outline,
      'timer': Icons.timer,
      'swing': Icons.swap_vert,
    };
    return map[name] ?? Icons.radio_button_unchecked;
  }

  static Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class IrRemoteControl extends StatelessWidget {
  const IrRemoteControl({
    required this.deviceId,
    required this.telemetry,
    required this.onRpc,
    this.buttonLayout = const [],
    super.key,
  });

  final String deviceId;
  final Map<String, dynamic> telemetry;

  /// List<Map> từ binding metadata "button_layout"
  final List<dynamic> buttonLayout;

  /// Callback: onRpc(method, params)
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;

  List<IrButtonMeta> get _buttons {
    if (buttonLayout.isEmpty) return _defaultButtons;
    return buttonLayout
        .whereType<Map<String, dynamic>>()
        .map(IrButtonMeta.fromJson)
        .toList()
      ..sort((a, b) {
        final rowCmp = a.row.compareTo(b.row);
        return rowCmp != 0 ? rowCmp : a.col.compareTo(b.col);
      });
  }

  static List<IrButtonMeta> get _defaultButtons => [
    const IrButtonMeta(action: 'toggle', label: 'Bật/Tắt', icon: Icons.power_settings_new, color: Colors.red, row: 0, col: 0),
  ];

  /// Tính số cột tối đa trong layout
  int get _colCount {
    if (buttonLayout.isEmpty) return 1;
    int maxCol = 0;
    for (final b in _buttons) {
      if (b.col > maxCol) maxCol = b.col;
    }
    return (maxCol + 1).clamp(1, 5);
  }

  /// Tổ chức buttons thành rows
  Map<int, List<IrButtonMeta>> get _buttonsByRow {
    final map = <int, List<IrButtonMeta>>{};
    for (final b in _buttons) {
      map.putIfAbsent(b.row, () => []).add(b);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isOn = telemetry['onoff0'] == 1 || telemetry['onoff0'] == true;
    final rows = _buttonsByRow;
    final sortedRowKeys = rows.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── Status indicator ──
        _StatusBar(telemetry: telemetry, isOn: isOn),
        const SizedBox(height: 20),

        // ── Remote body ──
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // IR indicator dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? Colors.deepOrange.shade400
                        : Colors.grey.shade600,
                    boxShadow: isOn
                        ? [
                            BoxShadow(
                              color: Colors.deepOrange.withValues(alpha: 0.6),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Button rows
                for (final rowKey in sortedRowKeys) ...[
                  _ButtonRow(
                    buttons: rows[rowKey]!,
                    colCount: _colCount,
                    onTap: _handleButtonTap,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Current state info ──
        _StateInfoPanel(telemetry: telemetry),
      ],
    );
  }

  void _handleButtonTap(BuildContext context, IrButtonMeta btn) {
    HapticFeedback.lightImpact();
    final params = btn.params ?? {};
    onRpc(btn.action, params);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gửi: ${btn.label}'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.telemetry, required this.isOn});
  final Map<String, dynamic> telemetry;
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (telemetry.containsKey('mode')) parts.add('Chế độ: ${telemetry['mode']}');
    if (telemetry.containsKey('temp')) parts.add('${telemetry['temp']}°C');
    if (telemetry.containsKey('volume')) parts.add('Vol: ${telemetry['volume']}');
    if (telemetry.containsKey('speed')) parts.add('Tốc: ${telemetry['speed']}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOn
            ? Colors.deepOrange.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOn
              ? Colors.deepOrange.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOn ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: isOn ? Colors.deepOrange : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOn
                  ? (parts.isEmpty ? 'Đang bật' : parts.join('  ·  '))
                  : 'Đang tắt',
              style: TextStyle(
                color: isOn ? Colors.deepOrange.shade700 : Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.buttons,
    required this.colCount,
    required this.onTap,
  });
  final List<IrButtonMeta> buttons;
  final int colCount;
  final void Function(BuildContext, IrButtonMeta) onTap;

  @override
  Widget build(BuildContext context) {
    // Place buttons in a row by col position
    return Row(
      children: List.generate(colCount, (col) {
        final btn = buttons.firstWhere(
          (b) => b.col == col,
          orElse: () => const IrButtonMeta(
            action: '_empty', label: '', icon: Icons.radio_button_unchecked,
            row: 0, col: 0,
          ),
        );
        if (btn.action == '_empty') return const Expanded(child: SizedBox());
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _RemoteButton(btn: btn, onTap: () => onTap(context, btn)),
          ),
        );
      }),
    );
  }
}

class _RemoteButton extends StatelessWidget {
  const _RemoteButton({required this.btn, required this.onTap});
  final IrButtonMeta btn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = btn.color ?? Colors.blueGrey.shade300;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(btn.icon, color: color, size: 20),
            const SizedBox(height: 2),
            if (btn.label.isNotEmpty)
              Text(
                btn.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _StateInfoPanel extends StatelessWidget {
  const _StateInfoPanel({required this.telemetry});
  final Map<String, dynamic> telemetry;

  static const _stateLabels = <String, String>{
    'onoff0': 'Trạng thái',
    'mode': 'Chế độ',
    'temp': 'Nhiệt độ',
    'fan_speed': 'Tốc quạt',
    'volume': 'Âm lượng',
    'speed': 'Tốc độ',
    'timer': 'Hẹn giờ (ph)',
    'swing': 'Xoay',
    'input': 'Nguồn vào',
  };

  @override
  Widget build(BuildContext context) {
    final entries = telemetry.entries
        .where((e) => _stateLabels.containsKey(e.key))
        .map((e) => (label: _stateLabels[e.key]!, value: e.value))
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trạng thái hiện tại',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in entries)
              _StateChip(label: e.label, value: e.value.toString()),
          ],
        ),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
