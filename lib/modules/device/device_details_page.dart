import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/device/gw/minihub_v1_models.dart';
import 'package:thingsboard_app/model/device/lumi_plug_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/modules/device/lumi_plug/lumi_plug_control_page.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'package:provider/provider.dart';

import 'gw/minihub_v1_control_page.dart';

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
      create: (_) {
        final json = entity.toJson();
        MyDeviceInfo device;
        if (json['type'] == 'lumi.plug') {
          device = LumiPlug.fromJson(json);
        } else if (json['type'] == 'Minihub V1') {
          device = MinihubV1.fromJson(json);
        } else {
          device = MyDeviceInfo.fromJson(json);
        }
        device.subscribe(widget.tbContext.tbClient);
        return device;
      },
      child: Consumer<MyDeviceInfo>(
        builder: (
          context,
          myDeviceInfo,
          child,
        ) {
          if (myDeviceInfo is LumiPlug) {
            return LumiPlugControlPage(widget.tbContext,
                lumiPlug: myDeviceInfo);
          } else if (myDeviceInfo is MinihubV1) {
            return MinihubV1ControlPage(widget.tbContext,
                minihub: myDeviceInfo);
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
