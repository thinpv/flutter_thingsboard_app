import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_models.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'component/if_page.dart';

class IfDevicesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<DeviceInfo> devices = DeviceManager.instance.deviceInfosList;
    return Scaffold(
      appBar: AppBar(title: Text('Chọn thiết bị')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.getDisplayName()),
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
