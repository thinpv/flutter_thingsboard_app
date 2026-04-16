import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/device_history_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/ac_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/air_quality_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/camera_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/curtain_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/device_detail_shared.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/door_sensor_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/electrical_switch_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/gateway_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/leak_sensor_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/light_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/lock_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/motion_sensor_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/ir_ac_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/ir_remote_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/remote_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/rf_fan_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/rf_socket_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/smart_plug_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/smoke_sensor_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/soil_sensor_view.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/switch_control.dart';
import 'package:thingsboard_app/modules/smarthome/device_detail/presentation/types/temp_hum_view.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/presentation/detail_composer.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/providers/profile_metadata_providers.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_control_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/home_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

// ─────────────────────────────────────────────────────────────────────────────

class DeviceDetailPage extends ConsumerStatefulWidget {
  const DeviceDetailPage({required this.device, super.key});

  final SmarthomeDevice device;

  @override
  ConsumerState<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends ConsumerState<DeviceDetailPage>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _telemetry;
  bool _isOnline = false;
  late String _displayName;
  TelemetrySubscriber? _telemetrySub;
  TelemetrySubscriber? _attrSub;
  final _control = DeviceControlService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _telemetry = Map.from(widget.device.telemetry);
    _isOnline = widget.device.isOnline;
    _displayName = widget.device.displayName;

    _telemetrySub = _control.subscribeToLatestTelemetry(widget.device.id);
    _telemetrySub!.attributeDataStream.listen((attrs) {
      if (mounted) {
        setState(() {
          for (final a in attrs) {
            _telemetry[a.key] = a.value;
          }
          _isOnline = _resolveOnline();
        });
      }
    });

    _attrSub = _control.subscribeToServerAttributes(
      widget.device.id,
      keys: ['active'],
    );
    _attrSub!.attributeDataStream.listen((attrs) {
      if (mounted) {
        setState(() {
          for (final a in attrs) {
            _telemetry[a.key] = a.value;
          }
          _isOnline = _resolveOnline();
        });
      }
    });
  }

  bool _resolveOnline() {
    final active = _telemetry['active'];
    if (active != null) {
      return active == true || active == 1 || active == 'true';
    }
    final stt = _telemetry['stt'];
    if (stt != null) return stt == 1 || stt == true || stt == 'true';
    return false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _telemetrySub?.unsubscribe();
    _attrSub?.unsubscribe();
    super.dispose();
  }

  final Map<String, DateTime> _lastRpcByKey = {};

  Future<void> _rpc(String method, Map<String, dynamic> params) async {
    // Debounce per-key: mỗi kênh điều khiển có timer riêng
    // → bấm onoff0 + onoff1 liên tiếp vẫn được, không bị chặn lẫn nhau
    final debounceKey = '$method:${(params.keys.toList()..sort()).join(',')}';
    final now = DateTime.now();
    final last = _lastRpcByKey[debounceKey];
    if (last != null && now.difference(last) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastRpcByKey[debounceKey] = now;

    try {
      await _control.sendOneWayRpc(widget.device.id, method, params);
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('409')
          ? 'Thiết bị không kết nối'
          : 'Lỗi điều khiển: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _deleteDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khỏi nhà'),
        content: Text(
          'Bỏ "${widget.device.displayName}" khỏi nhà của bạn?\n'
          'Thiết bị sẽ ngừng hiển thị nhưng dữ liệu không bị xóa khỏi máy chủ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final svc = HomeService();
      final gatewayId = await svc.findGatewayForDevice(widget.device.id);
      await svc.deleteDevice(widget.device.id, gatewayId: gatewayId);
      ref.invalidate(devicesInRoomProvider);
      ref.invalidate(devicesInHomeProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa thiết bị: $e')),
        );
      }
    }
  }

  Future<void> _editLabel() async {
    final controller = TextEditingController(text: _displayName);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên thiết bị'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập tên mới…'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (newLabel == null || newLabel.isEmpty || newLabel == _displayName) return;
    try {
      final client = getIt<ITbClientService>().client;
      final device = await client.getDeviceService().getDevice(widget.device.id);
      if (device == null) throw Exception('Không tìm thấy thiết bị');
      device.label = newLabel;
      await client.getDeviceService().saveDevice(device);
      if (mounted) {
        setState(() => _displayName = newLabel);
        ref.invalidate(devicesInRoomProvider);
        ref.invalidate(devicesInHomeProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editLabel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 16),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          _OnlineBadge(isOnline: _isOnline),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _deleteDevice();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Xóa khỏi nhà', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chi tiết'),
            Tab(text: 'Lịch sử'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBody(),
          DeviceHistoryView(
            deviceId: widget.device.id,
            telemetry: _telemetry,
          ),
        ],
      ),
    );
  }

  // ─── B-A-6: Route tới DetailComposer nếu profile metadata có states ──────

  Widget _buildBody() {
    final profileId = widget.device.deviceProfileId ?? '';
    // uiType ưu tiên: per-device server attr → profile description → device.type
    String uiType = widget.device.uiType ?? widget.device.type;

    if (profileId.isNotEmpty) {
      final metaAsync = ref.watch(deviceProfileMetadataProvider(profileId));
      final meta = metaAsync.valueOrNull;

      // Lấy uiType từ metadata nếu có (không phải 'auto'), kể cả khi states rỗng.
      // Điều này fix trường hợp device.uiType chưa resolve khi mở trang.
      if (meta != null && meta.uiType != 'auto') {
        uiType = meta.uiType;
      }

      // DetailComposer chỉ dùng khi uiType='auto' (profile mới, chưa có legacy view).
      // Các uiType cụ thể (smart_plug, light, door_sensor...) luôn dùng legacy view
      // đã thiết kế kỹ — SmartPlugControl, LightControl, DoorSensorView, v.v.
      if (meta != null && meta.states.isNotEmpty && uiType == 'auto') {
        return DetailComposer.build(context, meta, widget.device.id);
      }

      // Ưu tiên detailLayout từ profile (là tập hữu hạn widget types) để
      // routing không phụ thuộc vào uiType cụ thể — cho phép thêm thiết bị
      // mới mà không cần cập nhật app.
      final detailLayout = meta?.uiHints?.detailLayout;
      String routeKey = (detailLayout != null && detailLayout != 'auto')
          ? detailLayout
          : uiType;
      // Fallback: profile cụ thể của IR (ir_tv_lg, ir_tv_samsung, ir_fan_generic…)
      // đều dùng layout ir_remote. Xử lý trường hợp profile trên ThingsBoard
      // chưa có ui_hints.detail_layout (nhập trước khi field này được thêm).
      if (routeKey.startsWith('ir_') &&
          routeKey != 'ir_remote' &&
          routeKey != 'ir_ac') {
        routeKey = 'ir_remote';
      }
      return _buildLegacyBody(routeKey, meta: meta);
    }

    return _buildLegacyBody(uiType);
  }

  Widget _buildLegacyBody(String uiType, {ProfileMetadata? meta}) {
    return switch (uiType) {
      'light' => LightControl(
          telemetry: _telemetry,
          onRpc: _rpc,
          meta: meta ?? const ProfileMetadata(),
        ),
      'air_conditioner' => AcControl(telemetry: _telemetry, onRpc: _rpc),
      'smart_plug' => SmartPlugControl(
          deviceId: widget.device.id,
          deviceName: widget.device.displayName,
          telemetry: _telemetry,
          onRpc: _rpc,
        ),
      'curtain' => CurtainControl(telemetry: _telemetry, onRpc: _rpc),
      'switch' => SwitchControl(telemetry: _telemetry, onRpc: _rpc, meta: meta),
      'electrical_switch' =>
        ElectricalSwitchView(telemetry: _telemetry, onRpc: _rpc, meta: meta),
      'door_sensor' => DoorSensorView(
          deviceId: widget.device.id,
          deviceName: widget.device.displayName,
          telemetry: _telemetry,
        ),
      'motion_sensor' => MotionSensorView(telemetry: _telemetry),
      'temp_humidity' => TempHumView(telemetry: _telemetry),
      'smoke_sensor' => SmokeSensorView(telemetry: _telemetry),
      'leak_sensor' => LeakSensorView(telemetry: _telemetry),
      'air_quality' => AirQualityView(telemetry: _telemetry),
      'soil_sensor' => SoilSensorView(telemetry: _telemetry),
      'lock' => LockView(telemetry: _telemetry, onRpc: _rpc),
      'remote' || 'button' || 'scene_switch' => RemoteView(telemetry: _telemetry),

      // IR devices — routing theo detailLayout từ profile (ir_remote | ir_ac).
      // button_layout lấy từ profile ui_hints, không hardcode trong app.
      // Profile riêng mỗi loại thiết bị (ir_tv_lg, ir_tv_samsung, ir_fan_generic...)
      // đều có detail_layout="ir_remote" → route vào đây với button_layout riêng.
      'ir_remote' => IrRemoteControl(
          deviceId: widget.device.id,
          telemetry: _telemetry,
          onRpc: (method, params) => _rpc(method, params),
          buttonLayout: meta?.uiHints?.buttonLayout ?? const [],
        ),
      'ir_ac' => IrAcControl(
          deviceName: widget.device.displayName,
          telemetry: _telemetry,
          onRpc: (method, params) => _rpc(method, params),
          minTemp: meta?.uiHints?.irAcConfig?.minTemp ?? 16,
          maxTemp: meta?.uiHints?.irAcConfig?.maxTemp ?? 30,
          supportedModes: meta?.uiHints?.irAcConfig?.modes ??
              const ['cool', 'heat', 'fan', 'dry', 'auto'],
          supportedFanSpeeds: meta?.uiHints?.irAcConfig?.fanSpeeds ??
              const ['auto', 'low', 'mid', 'high'],
        ),

      // RF devices — routing theo detailLayout từ profile
      'rf_fan' => RfFanControl(
          telemetry: _telemetry,
          onRpc: (method, params) => _rpc(method, params),
        ),
      'rf_socket' => RfSocketView(
          telemetry: _telemetry,
          onRpc: (method, params) => _rpc(method, params),
        ),
      'rf_doorbell' => RfDoorbellView(telemetry: _telemetry),

      'camera' => CameraView(telemetry: _telemetry, onRpc: _rpc),
      'gateway' => GatewayView(telemetry: _telemetry, onRpc: _rpc),
      _ => _GenericView(telemetry: _telemetry),
    };
  }
}

// ─── Online badge (AppBar-specific) ──────────────────────────────────────────

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.isOnline});
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOnline ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generic fallback view ────────────────────────────────────────────────────

class _GenericView extends StatelessWidget {
  const _GenericView({required this.telemetry});
  final Map<String, dynamic> telemetry;

  @override
  Widget build(BuildContext context) {
    final entries = telemetry.entries
        .where((e) => e.key != 'active' && e.key != 'stt')
        .toList();
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text('Chưa có dữ liệu telemetry'),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: entries
          .map((e) => DetailRow(
                icon: Icons.data_usage,
                label: e.key,
                value: '${e.value}',
              ))
          .toList(),
    );
  }
}
