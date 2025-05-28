import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceDetailsPage extends StatefulWidget {
  final TbContext tbContext;
  final String deviceId;

  const DeviceDetailsPage(this.tbContext, this.deviceId, {super.key});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  late Future<Device?> _deviceFuture;

  @override
  void initState() {
    super.initState();
    _deviceFuture = fetchEntity(widget.deviceId);
  }

  Future<Device?> fetchEntity(String id) async {
    return DeviceManager.instance.getDeviceById(id);
  }

  void _refresh() {
    setState(() {
      _deviceFuture = fetchEntity(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Device?>(
      future: _deviceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
              body: Center(child: Text('Không tìm thấy thiết bị')));
        }
        return _buildEntityDetails(context, snapshot.data!);
      },
    );
  }

  Widget _buildEntityDetails(BuildContext context, Device entity) {
    return Scaffold(
      appBar: AppBar(title: Text(entity.name)),
      body: ListTile(
        title: Text(entity.name),
        subtitle: Text(entity.type),
      ),
    );
  }
}
