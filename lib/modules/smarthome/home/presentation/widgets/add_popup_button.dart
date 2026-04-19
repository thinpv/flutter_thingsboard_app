import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_room.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/room_provider.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/automation_edit_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/add_device_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/claim_device_page.dart';

/// Nút + dùng chung ở Home tab và Smart tab.
/// Hiện dropdown ngay bên dưới nút với 3 lựa chọn:
///   - Thêm thiết bị
///   - Quét mã thiết bị
///   - Tạo kịch bản
class SmarthomeAddButton extends ConsumerStatefulWidget {
  const SmarthomeAddButton({super.key});

  @override
  ConsumerState<SmarthomeAddButton> createState() => _SmarthomeAddButtonState();
}

class _SmarthomeAddButtonState extends ConsumerState<SmarthomeAddButton> {
  final _key = GlobalKey();
  OverlayEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context)) _dismiss();
  }

  void _toggle() {
    if (_entry != null) {
      _dismiss();
      return;
    }
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final screenSize = MediaQuery.of(context).size;
    final origin = box.localToGlobal(Offset.zero);
    final btnRight = origin.dx + box.size.width;
    final menuTop = origin.dy + box.size.height + 6;
    final menuRight = screenSize.width - btnRight;

    _entry = OverlayEntry(
      builder: (_) => _AddMenu(
        top: menuTop,
        right: menuRight,
        onDismiss: _dismiss,
        onSelected: _onSelected,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  void _onSelected(String val) {
    _dismiss();
    switch (val) {
      case 'device':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDevicePage()),
        ).then((_) {
          final home = ref.read(selectedHomeProvider).valueOrNull;
          if (home != null) {
            ref.invalidate(devicesInHomeProvider(home.id));
            for (final SmarthomeRoom r
                in ref.read(roomsProvider).valueOrNull ?? []) {
              ref.invalidate(devicesInRoomProvider(r.id));
            }
          }
        });
      case 'qr':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClaimDevicePage()),
        );
      case 'scene':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AutomationEditPage(isTapToRun: true)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      onTap: _toggle,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MpColors.surface,
          border: Border.all(color: MpColors.border),
        ),
        child: const Icon(Icons.add, size: 18, color: MpColors.text2),
      ),
    );
  }
}

// ─── Overlay menu ─────────────────────────────────────────────────────────────

class _AddMenu extends StatelessWidget {
  const _AddMenu({
    required this.top,
    required this.right,
    required this.onDismiss,
    required this.onSelected,
  });

  final double top;
  final double right;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            onPanDown: (_) => onDismiss(),
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
        Positioned(
          top: top,
          right: right,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: MpColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _item('device', Icons.devices_other_outlined, MpColors.blueSoft,
                      MpColors.blue, 'Thêm thiết bị', 'Ghép nối thiết bị mới'),
                  Divider(height: 1, color: MpColors.border),
                  _item('qr', Icons.qr_code_scanner, MpColors.greenSoft,
                      MpColors.green, 'Quét mã thiết bị', 'Thêm bằng mã QR'),
                  Divider(height: 1, color: MpColors.border),
                  _item('scene', Icons.auto_awesome_outlined, MpColors.amberSoft,
                      MpColors.amber, 'Tạo kịch bản', 'Thêm scene mới'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(String val, IconData icon, Color tint, Color iconColor,
      String title, String subtitle) {
    return GestureDetector(
      onTap: () => onSelected(val),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: tint, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MpColors.text)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: MpColors.text3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
