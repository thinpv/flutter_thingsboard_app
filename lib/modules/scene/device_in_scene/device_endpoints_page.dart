import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';

class DeviceEndpointsPage extends StatelessWidget {
  final String deviceId;
  const DeviceEndpointsPage(this.deviceId, {super.key});

  @override
  Widget build(BuildContext context) {
    MyDeviceInfo? myDeviceInfo =
        DeviceManager.instance.getMyDeviceInfoById(deviceId);
    DeviceTypeInfo? deviceType = myDeviceInfo?.deviceProfileId?.id != null
        ? DeviceTypeManager.instance
            .getDeviceTypeById(myDeviceInfo!.deviceProfileId!.id!)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn chức năng')),
      body: deviceType?.endpoints != null
          ? ListView.builder(
              itemCount: deviceType!.endpoints.length,
              itemBuilder: (context, index) {
                final option = deviceType.endpoints[index];
                return ListTile(
                  title: Text(option['name'].toString()),
                  onTap: () async {
                    DeviceInScene deviceInScene = DeviceInScene(
                      deviceId,
                      epId: option['id'] as int?,
                      epName: option['name'],
                    );
                    Navigator.pop(context, deviceInScene);
                  },
                );
              },
            )
          : const Center(child: Text('No endpoints available')),
    );
  }
}
