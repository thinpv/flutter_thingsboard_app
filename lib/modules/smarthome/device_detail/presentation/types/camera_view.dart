import 'package:flutter/material.dart';

import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';

// Keys: pir (motion detection)
// RPC: ptz_control {pan, tilt, zoom}, snapshot
class CameraView extends StatefulWidget {
  const CameraView({required this.telemetry, required this.onRpc, super.key});
  final Map<String, dynamic> telemetry;
  final Future<void> Function(String method, Map<String, dynamic> params) onRpc;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _snapshotLoading = false;

  bool get _motionDetected => isOn(widget.telemetry['pir']);

  Future<void> _ptz(int pan, int tilt) =>
      widget.onRpc('ptz_control', {'pan': pan, 'tilt': tilt, 'zoom': 0});

  Future<void> _zoom(int z) =>
      widget.onRpc('ptz_control', {'pan': 0, 'tilt': 0, 'zoom': z});

  Future<void> _snapshot() async {
    setState(() => _snapshotLoading = true);
    try {
      await widget.onRpc('snapshot', {});
    } finally {
      if (mounted) setState(() => _snapshotLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motionDetected;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // ── Camera preview placeholder ──
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.videocam_outlined,
                  size: 64,
                  color: Colors.grey.shade600,
                ),
              ),
              // Motion badge
              if (motion)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_walk, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'CHUYỂN ĐỘNG',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Live badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Snapshot button ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _snapshotLoading ? null : _snapshot,
            icon: _snapshotLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined),
            label: const Text('Chụp ảnh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── PTZ controls ──
        Text(
          'Điều hướng camera (PTZ)',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        // D-pad
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                  child: Icon(Icons.crop_free, color: Colors.grey.shade400),
                ),
                // Up
                Positioned(
                  top: 0,
                  child: _PtzButton(
                    icon: Icons.keyboard_arrow_up,
                    onTap: () => _ptz(0, 1),
                  ),
                ),
                // Down
                Positioned(
                  bottom: 0,
                  child: _PtzButton(
                    icon: Icons.keyboard_arrow_down,
                    onTap: () => _ptz(0, -1),
                  ),
                ),
                // Left
                Positioned(
                  left: 0,
                  child: _PtzButton(
                    icon: Icons.keyboard_arrow_left,
                    onTap: () => _ptz(-1, 0),
                  ),
                ),
                // Right
                Positioned(
                  right: 0,
                  child: _PtzButton(
                    icon: Icons.keyboard_arrow_right,
                    onTap: () => _ptz(1, 0),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Zoom
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PtzButton(
              icon: Icons.zoom_out,
              onTap: () => _zoom(-1),
              size: 52,
              iconSize: 28,
            ),
            const SizedBox(width: 8),
            const Text('Zoom', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 8),
            _PtzButton(
              icon: Icons.zoom_in,
              onTap: () => _zoom(1),
              size: 52,
              iconSize: 28,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Motion status ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: motion ? Colors.orange.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: motion ? Colors.orange.shade200 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                motion ? Icons.directions_walk : Icons.motion_photos_off_outlined,
                color: motion ? Colors.orange : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                motion ? 'Phát hiện chuyển động!' : 'Không có chuyển động',
                style: TextStyle(
                  color: motion ? Colors.orange.shade800 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PtzButton extends StatelessWidget {
  const _PtzButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.iconSize = 24,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: Colors.grey.shade700),
      ),
    );
  }
}
