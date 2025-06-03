import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';

class ThenPage extends StatelessWidget {
  final SceneAction action;
  ThenPage(this.action, {super.key});

  @override
  Widget build(BuildContext context) {
    MyDeviceInfo? myDeviceInfo =
        DeviceManager.instance.getMyDeviceInfoById(action.device);
    DeviceTypeInfo? deviceType = myDeviceInfo?.deviceProfileId?.id != null
        ? DeviceTypeManager.instance
            .getDeviceTypeById(myDeviceInfo!.deviceProfileId!.id!)
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
                    action.action = option['value'].toString();
                    Navigator.pop(context, action);
                  },
                );
              },
            )
          : Center(child: Text('No actions available')),
    );
  }
}
