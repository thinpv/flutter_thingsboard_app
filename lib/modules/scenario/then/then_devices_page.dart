import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_models.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'component/then_page.dart';

class ThenDevicesPage extends StatelessWidget {
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
              SceneAction action = SceneAction(device.id!.id!, '', {});
              final result = await Navigator.push<SceneAction>(
                context,
                MaterialPageRoute(builder: (context) => ThenPage(action)),
              );
              Navigator.pop(context, result);
            },
          );
        },
      ),
    );
  }
}
