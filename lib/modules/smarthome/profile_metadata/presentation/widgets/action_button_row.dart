import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/ui_hints.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/device_state_providers.dart';

/// Dải nút action nhanh cho detail page — mỗi nút gọi một RPC method.
///
/// Nhận danh sách [QuickAction] từ [UiHints.quickActions] và render
/// dưới dạng hàng ngang [OutlinedButton].
///
/// Ví dụ dùng cho rèm: open / close / stop.
/// Ví dụ dùng cho cửa khoá: unlock / lock.
class ActionButtonRow extends ConsumerWidget {
  const ActionButtonRow({
    required this.deviceId,
    required this.actions,
    super.key,
  });

  final String deviceId;
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: actions.map((a) => _ActionButton(
              deviceId: deviceId,
              action: a,
              ref: ref,
            )).toList(),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.deviceId,
    required this.action,
    required this.ref,
  });

  final String deviceId;
  final QuickAction action;
  final WidgetRef ref;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.ref
          .read(deviceControlServiceProvider)
          .sendOneWayRpc(widget.deviceId, widget.action.method, {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _onTap,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_iconData(widget.action.icon), size: 18),
      label: Text(widget.action.label),
    );
  }

  IconData _iconData(String name) => switch (name) {
        'open' || 'arrow_upward' => Icons.arrow_upward,
        'close' || 'arrow_downward' => Icons.arrow_downward,
        'stop' || 'stop_circle' => Icons.stop_circle_outlined,
        'lock' || 'lock_outline' => Icons.lock_outline,
        'lock_open' || 'unlock' => Icons.lock_open_outlined,
        'power' || 'power_settings_new' => Icons.power_settings_new,
        'toggle' || 'swap_vert' || 'swap_horiz' => Icons.swap_vert_rounded,
        'refresh' => Icons.refresh,
        'settings' => Icons.settings_outlined,
        _ => Icons.touch_app_outlined,
      };
}
