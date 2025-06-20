import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';

import 'device_endpoints_page.dart';

class ListDevicesPage extends StatelessWidget {
  const ListDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<MyDeviceInfo> devices = DeviceManager.instance.myDeviceInfosList;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn chức năng')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.getDisplayName()),
            onTap: () async {
              MyDeviceInfo? myDeviceInfo =
                  DeviceManager.instance.getMyDeviceInfoById(device.id!.id!);
              DeviceTypeInfo? deviceType =
                  myDeviceInfo?.deviceProfileId?.id != null
                      ? DeviceTypeManager.instance
                          .getDeviceTypeById(myDeviceInfo!.deviceProfileId!.id!)
                      : null;
              if (deviceType != null) {
                if (deviceType.endpoints.isEmpty) {
                  Navigator.pop(context, DeviceInScene(device.id!.id!));
                } else if (deviceType.endpoints.length == 1) {
                  DeviceInScene deviceInScene = DeviceInScene(
                    device.id!.id!,
                    epId: deviceType.endpoints[0]['id'] as int?,
                    epName: deviceType.endpoints[0]['name'],
                  );
                  Navigator.pop(context, deviceInScene);
                } else if (deviceType.endpoints.length >= 2) {
                  final result = await Navigator.push<DeviceInScene>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceEndpointsPage(device.id!.id!),
                    ),
                  );
                  Navigator.pop(context, result);
                }
              } else {
                Navigator.pop(context, DeviceInScene(device.id!.id!));
              }
            },
          );
        },
      ),
    );
  }
}
