import 'package:flutter/material.dart';
import 'package:thingsboard_app/provider/DeviceManager.dart';

import 'component/if_page_switch_2.dart';

class IfDevicesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: DeviceManager.instance.getDevices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text('Chọn thiết bị')),
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Chọn thiết bị')),
            body: Center(child: Text('Lỗi khi tải thiết bị')),
          );
        } else {
          final devices = snapshot.data ?? [];
          return Scaffold(
            appBar: AppBar(title: Text('Chọn thiết bị')),
            body: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.name),
                  onTap: () async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                          builder: (context) => IfPageSwitch2(device)),
                    );
                    if (result != null) {
                      Map<String, dynamic> data = {};
                      data['name'] = device.name;
                      data['data'] = result;
                      Navigator.pop(context, data);
                    }
                  },
                );
              },
            ),
          );
        }
      },
    );
  }
}
