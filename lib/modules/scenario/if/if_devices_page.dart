import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'component/if_page_switch_2.dart';

class IfDevicesPage extends StatelessWidget {
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
              SceneCondition condition = SceneCondition.empty(device);
              final result = await Navigator.push<SceneCondition>(
                context,
                MaterialPageRoute(
                    builder: (context) => IfPageSwitch2(condition)),
              );
              Navigator.pop(context, result);
            },
          );
        },
      ),
    );
  }
}
