import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';

class ListDevicesMultiPage extends StatefulWidget {
  const ListDevicesMultiPage({super.key});

  @override
  State<ListDevicesMultiPage> createState() => _ListDevicesMultiPageState();
}

class _ListDevicesMultiPageState extends State<ListDevicesMultiPage> {
  final Set<String> selectedDeviceIds = {};

  @override
  Widget build(BuildContext context) {
    List<MyDeviceInfo> devices = DeviceManager.instance.myDeviceInfosList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn thiết bị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done),
            onPressed: () {
              final selected =
                  selectedDeviceIds.map((id) => DeviceInRoom(id)).toList();
              Navigator.pop(context, selected); // Trả về danh sách đã chọn
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final deviceId = device.id!.id!;
          final isSelected = selectedDeviceIds.contains(deviceId);

          return CheckboxListTile(
            title: Text(device.getDisplayName()),
            value: isSelected,
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  selectedDeviceIds.add(deviceId);
                } else {
                  selectedDeviceIds.remove(deviceId);
                }
              });
            },
          );
        },
      ),
    );
  }
}
