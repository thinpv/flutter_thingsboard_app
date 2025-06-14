import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/device/lumi_plug_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/modules/device/device_details/lumi_plug_widget.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'package:provider/provider.dart';

class DeviceDetailsPage extends StatefulWidget {
  final TbContext tbContext;
  final String deviceId;

  const DeviceDetailsPage(this.tbContext, this.deviceId, {super.key});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  late Future<MyDeviceInfo?> _deviceFuture;

  @override
  void initState() {
    super.initState();
    _deviceFuture = fetchEntity(widget.deviceId);
  }

  Future<MyDeviceInfo?> fetchEntity(String id) async {
    return DeviceManager.instance.getMyDeviceInfoById(id);
  }

  void _refresh() {
    setState(() {
      _deviceFuture = fetchEntity(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyDeviceInfo?>(
      future: _deviceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Không tìm thấy thiết bị')),
          );
        }
        return _buildEntityDetails(context, snapshot.data!);
      },
    );
  }

  Widget _buildEntityDetails(BuildContext context, MyDeviceInfo entity) {
    return ChangeNotifierProvider<MyDeviceInfo>(
      create: (_) => LumiPlug.fromJson(entity.toJson())
        ..subscribe(widget.tbContext.tbClient),
      child: Consumer<MyDeviceInfo>(
        builder: (
          context,
          myDeviceInfo,
          child,
        ) {
          if (myDeviceInfo is LumiPlug) {
            return LumiPlugWidget(lumiPlug: myDeviceInfo);
          } else {
            return ListTile(
              title: Text(myDeviceInfo.getDisplayName()),
              subtitle: Text(myDeviceInfo.type + myDeviceInfo.toString()),
            );
          }
        },
      ),
    );
  }
}
