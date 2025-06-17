import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

import 'component/if_device_conditions_page.dart';

class IfDevicesPage extends StatelessWidget {
  const IfDevicesPage({super.key});

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
              final result = await Navigator.push<RuleConditionDevice>(
                context,
                MaterialPageRoute(
                  builder: (context) => IfDeviceConditionsPage(device.id!.id!),
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
