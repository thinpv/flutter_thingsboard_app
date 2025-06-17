import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'component/then_device_actions_page.dart';

class ThenDevicesPage extends StatelessWidget {
  const ThenDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<MyDeviceInfo> devices = DeviceManager.instance.myDeviceInfosList;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn thiết bị')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.getDisplayName()),
            onTap: () async {
              final result = await Navigator.push<RuleActionDevice>(
                context,
                MaterialPageRoute(
                  builder: (context) => ThenDeviceActionsPage(device.id!.id!),
                ),
              );
              Navigator.pop(context, result);
            },
          );
        },
      ),
    );
  }
}
