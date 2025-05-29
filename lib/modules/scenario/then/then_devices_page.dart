import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'component/then_page_switch_2.dart';

class ThenDevicesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final devices = DeviceManager.instance.devices;
    return Scaffold(
      appBar: AppBar(title: Text('Chọn thiết bị')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.name),
            onTap: () async {
              SceneAction action = SceneAction.empty(device);
              final result = await Navigator.push<SceneAction>(
                context,
                MaterialPageRoute(
                    builder: (context) => ThenPageSwitch2(action)),
              );
              Navigator.pop(context, result);
            },
          );
        },
      ),
    );
  }
}
