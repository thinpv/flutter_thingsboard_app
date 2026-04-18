import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';

/// Bước 4: Thử phím — User ấn từng nút, gateway phát IR/RF thật.
/// Nếu thiết bị phản hồi đúng → nhấn "Chọn remote này" để tiếp tục.
class CodesetTestPage extends StatefulWidget {
  const CodesetTestPage({
    super.key,
    required this.profile,
    required this.gatewayId,
  });

  final CodesetProfile profile;
  final String gatewayId;

  @override
  State<CodesetTestPage> createState() => _CodesetTestPageState();
}

class _CodesetTestPageState extends State<CodesetTestPage> {
  final _control = DeviceControlService();

  String? _sendingAction;
  String? _lastResult; // 'ok' | 'error'
  String? _lastAction;

  Future<void> _testButton(Map<String, dynamic> button) async {
    final action = button['action'] as String;
    final proto = button['proto'] as Map<String, dynamic>?;
    if (proto == null) return;

    setState(() {
      _sendingAction = action;
      _lastResult = null;
    });

    final rpcMethod = widget.profile.protocol == 'rf' ? 'rfTestCode' : 'irTestCode';

    try {
      final resp = await _control.sendTwoWayRpc(
        widget.gatewayId,
        rpcMethod,
        {'proto': proto},
        timeout: 8000,
      );
      final code = resp?['code'] as int? ?? -1;
      setState(() {
        _sendingAction = null;
        _lastResult = code == 0 ? 'ok' : 'error';
        _lastAction = action;
      });
    } catch (e) {
      setState(() {
        _sendingAction = null;
        _lastResult = 'error';
        _lastAction = action;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final testBtns = profile.testButtons;
    final isRf = profile.protocol == 'rf';

    return Scaffold(
      appBar: AppBar(
        title: Text('Thử remote — ${profile.displayName ?? profile.modelId}'),
      ),
      body: Column(
        children: [
          // Status banner
          if (_lastResult != null)
            _StatusBanner(result: _lastResult!, action: _lastAction),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hướng dẫn
                  _InfoCard(isRf: isRf),
                  const SizedBox(height: 20),

                  const Text('Ấn các nút bên dưới',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: MpColors.text3, letterSpacing: 0.4)),
                  const SizedBox(height: 12),

                  // Test buttons grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                    children: testBtns.map((btn) {
                      return _TestButton(
                        button: btn,
                        isSending: _sendingAction == btn['action'],
                        lastResult: _lastAction == btn['action']
                            ? _lastResult
                            : null,
                        onTap: () => _testButton(btn),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  // Note about more buttons
                  if (profile.buttonLayout.length > testBtns.length)
                    Text(
                      '+ ${profile.buttonLayout.length - testBtns.length} nút khác sẽ có sau khi thêm thiết bị.',
                      style: const TextStyle(fontSize: 12, color: MpColors.text3),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: MpColors.text,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Chọn remote này',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MpColors.bg)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      alignment: Alignment.center,
                      child: const Text('Remote không khớp — thử remote khác',
                          style: TextStyle(fontSize: 14, color: MpColors.text2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isRf});
  final bool isRf;

  @override
  Widget build(BuildContext context) {
    final text = isRf
        ? 'Ấn nút Bật/Tắt — đảm bảo thiết bị RF trong tầm phủ sóng. '
            'Nếu thiết bị phản hồi đúng → remote này phù hợp!'
        : 'Hướng gateway về phía thiết bị IR, ấn nút Power. '
            'Nếu thiết bị bật/tắt → remote này phù hợp!';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined, size: 18, color: MpColors.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.result, this.action});
  final String result;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final isOk = result == 'ok';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isOk ? MpColors.greenSoft : MpColors.redSoft,
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error_outline,
            color: isOk ? MpColors.green : MpColors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isOk ? 'Đã phát tín hiệu — thiết bị có phản hồi không?' : 'Không gửi được — kiểm tra kết nối gateway',
            style: TextStyle(fontSize: 13, color: isOk ? MpColors.green : MpColors.red),
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.button,
    required this.isSending,
    required this.lastResult,
    required this.onTap,
  });
  final Map<String, dynamic> button;
  final bool isSending;
  final String? lastResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = button['label'] as String? ?? (button['action'] as String);
    Color borderColor = MpColors.border;
    Color? bgColor;
    Color textColor = MpColors.text;
    if (lastResult == 'ok') {
      borderColor = MpColors.green;
      bgColor = MpColors.greenSoft;
      textColor = MpColors.green;
    } else if (lastResult == 'error') {
      borderColor = MpColors.red;
      bgColor = MpColors.redSoft;
      textColor = MpColors.red;
    }

    return GestureDetector(
      onTap: isSending ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: lastResult != null ? 1.5 : 0.5),
          borderRadius: BorderRadius.circular(8),
          color: bgColor ?? MpColors.surface,
        ),
        child: isSending
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (lastResult == 'ok')
                      const Icon(Icons.check, size: 16, color: MpColors.green)
                    else if (lastResult == 'error')
                      const Icon(Icons.close, size: 16, color: MpColors.red)
                    else
                      const Icon(Icons.send, size: 14, color: MpColors.text3),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
