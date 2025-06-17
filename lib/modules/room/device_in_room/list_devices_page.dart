import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

class ListDevicesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<MyDeviceInfo> devices = DeviceManager.instance.myDeviceInfosList;
    return Scaffold(
      appBar: AppBar(title: Text('Chọn thiết bị')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.getDisplayName()),
            onTap: () async {
              Navigator.pop(context, device);
            },
          );
        },
      ),
    );
  }
}
