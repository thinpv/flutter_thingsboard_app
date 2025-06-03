import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'component/if_page.dart';

class IfDevicesPage extends StatelessWidget {
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
            title: Text(device.displayName ?? device.name),
            onTap: () async {
              SceneCondition condition = SceneCondition(device.id!.id!, '', {});
              final result = await Navigator.push<SceneCondition>(
                context,
                MaterialPageRoute(builder: (context) => IfPage(condition)),
              );
              Navigator.pop(context, result);
            },
          );
        },
      ),
    );
  }
}
