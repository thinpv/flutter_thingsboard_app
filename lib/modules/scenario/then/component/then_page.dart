import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class ThenPage extends StatelessWidget {
  final SceneCondition condition;
  ThenPage(this.condition, {super.key});

  @override
  Widget build(BuildContext context) {
    DeviceInfo? deviceInfo =
        DeviceManager.instance.getDeviceById(condition.device);
    DeviceTypeInfo? deviceType = deviceInfo?.deviceProfileId?.id != null
        ? DeviceTypeManager.instance
            .getDeviceTypeById(deviceInfo!.deviceProfileId!.id!)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text('Chọn hành động')),
      body: deviceType?.actions != null
          ? ListView.builder(
              itemCount: deviceType!.actions.length,
              itemBuilder: (context, index) {
                final option = deviceType.actions[index];
                return ListTile(
                  title: Text(option['name'].toString()),
                  onTap: () async {
                    condition.condition = option['value'].toString();
                    Navigator.pop(context, condition);
                  },
                );
              },
            )
          : Center(child: Text('No actions available')),
    );
  }
}
