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
                    final values = option['value'];
                    if (values.toString().contains('?')) {
                      final List<String> fieldNames = [];
                      final List<TextEditingController> controllers = [];
                      values.forEach((key, value) {
                        if (value.toString().contains('?')) {
                          fieldNames.add(key);
                          controllers.add(TextEditingController());
                        }
                      });
                      final newValue = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Nhập thông tin'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children:
                                    List.generate(fieldNames.length, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: TextField(
                                      controller: controllers[index],
                                      decoration: InputDecoration(
                                        labelText: fieldNames[index],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // Lấy dữ liệu từ các TextField
                                  Map<String, String> inputData = {};
                                  for (var i = 0; i < fieldNames.length; i++) {
                                    inputData[fieldNames[i]] =
                                        controllers[i].text;
                                  }
                                  Navigator.pop(context, inputData);
                                },
                                child: Text('Lưu'),
                              )
                            ],
                          );
                        },
                      );
                      action.action = newValue.toString();
                    } else {
                      action.action = option['value'].toString();
                    }
                    Navigator.pop(context, action);
                  },
                );
              },
            )
          : Center(child: Text('No actions available')),
    );
  }
}
