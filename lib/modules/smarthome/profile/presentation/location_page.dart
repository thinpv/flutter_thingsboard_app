import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({required this.homeId, this.isSetup = false, super.key});

  final String homeId;
  /// True khi được mở ngay sau khi tạo nhà — hiển thị hint + nút Bỏ qua.
  final bool isSetup;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  double? _lat;
  double? _lng;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    try {
      final loc = await HomeService().fetchHomeLocation(widget.homeId);
      if (loc != null) {
        setState(() {
          _lat = (loc['lat'] as num?)?.toDouble();
          _lng = (loc['lng'] as num?)?.toDouble();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _error = null);

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _error = 'Quyền truy cập vị trí bị từ chối');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _error =
          'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng mở Cài đặt để cấp quyền.');
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      setState(() => _error = 'Không thể lấy vị trí: $e');
    }
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) return;
    setState(() => _saving = true);
    try {
      await HomeService().saveHomeLocation(widget.homeId, _lat!, _lng!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu vị trí')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSetup ? 'Xác định vị trí nhà' : 'Vị trí nhà'),
        elevation: 0,
        actions: widget.isSetup
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Bỏ qua'),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Setup hint ───────────────────────────────────
                        if (widget.isSetup) ...[
                          const Text(
                            'Vị trí nhà dùng để hiển thị thời tiết (nhiệt độ, độ ẩm) khi chưa có cảm biến nào trong nhà.',
                            style: TextStyle(fontSize: 13, color: MpColors.text2),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Location display ─────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: MpColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: MpColors.border, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 48,
                                color: _lat != null ? MpColors.text : MpColors.text3,
                              ),
                              const SizedBox(height: 12),
                              if (_lat != null && _lng != null) ...[
                                Text(
                                  'Vĩ độ: ${_lat!.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kinh độ: ${_lng!.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 14),
                                ),
                              ] else
                                const Text(
                                  'Chưa có vị trí',
                                  style: TextStyle(color: MpColors.text3),
                                ),
                            ],
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: MpColors.red, fontSize: 13),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ── Get GPS button ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Lấy vị trí GPS hiện tại'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Save button ───────────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _lat != null && !_saving ? _save : null,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Lưu vị trí'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
