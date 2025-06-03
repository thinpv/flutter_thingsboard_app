import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';

class IfPage extends StatelessWidget {
  final SceneCondition condition;
  IfPage(this.condition, {super.key});

  @override
  Widget build(BuildContext context) {
    MyDeviceInfo? myDeviceInfo =
        DeviceManager.instance.getMyDeviceInfoById(condition.device);
    DeviceTypeInfo? deviceType = myDeviceInfo?.deviceProfileId?.id != null
        ? DeviceTypeManager.instance
            .getDeviceTypeById(myDeviceInfo!.deviceProfileId!.id!)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text('Chọn thuộc tính')),
      body: deviceType?.conditions != null
          ? ListView.builder(
              itemCount: deviceType!.conditions.length,
              itemBuilder: (context, index) {
                final option = deviceType.conditions[index];
                return ListTile(
                  title: Text(option['name'].toString()),
                  onTap: () async {
                    condition.name = option['name'].toString();
                    condition.condition = option['value'];
                    Navigator.pop(context, condition);
                  },
                );
              },
            )
          : Center(child: Text('No conditions available')),
    );
  }
}
