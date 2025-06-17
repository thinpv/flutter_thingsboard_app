import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thingsboard_app/model/device_type_models.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';

class IfDeviceParamsPage extends StatelessWidget {
  final String deviceId;
  const IfDeviceParamsPage(this.deviceId, {super.key});

  @override
  Widget build(BuildContext context) {
    MyDeviceInfo? myDeviceInfo =
        DeviceManager.instance.getMyDeviceInfoById(deviceId);
    DeviceTypeInfo? deviceType = myDeviceInfo?.deviceProfileId?.id != null
        ? DeviceTypeManager.instance
            .getDeviceTypeById(myDeviceInfo!.deviceProfileId!.id!)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn thuộc tính')),
      body: deviceType?.conditions != null
          ? ListView.builder(
              itemCount: deviceType!.conditions.length,
              itemBuilder: (context, index) {
                final option = deviceType.conditions[index];
                return ListTile(
                  title: Text(option['name'].toString()),
                  onTap: () async {
                    final values = option['value'];
                    if (values.toString().contains('?')) {
                      final List<String> fieldNames = [];
                      final List<TextEditingController> controllers = [];
                      final Map<String, dynamic> inputData = {};
                      values.forEach((key, value) {
                        if (value.toString().contains('?')) {
                          fieldNames.add(key);
                          controllers.add(TextEditingController());
                          inputData[key] = value;
                        }
                      });
                      final newValue = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Nhập thông tin'),
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
                                      keyboardType: values[fieldNames[index]]
                                                  .toLowerCase() ==
                                              '?number'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      inputFormatters: values[fieldNames[index]]
                                                  .toLowerCase() ==
                                              '?number'
                                          ? [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d+\.?\d{0,2}'),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  for (var i = 0; i < fieldNames.length; i++) {
                                    String dataType = values[fieldNames[i]];
                                    if (dataType.toLowerCase() == '?string') {
                                      inputData[fieldNames[i]] =
                                          controllers[i].text;
                                    } else if (dataType.toLowerCase() ==
                                        '?number') {
                                      inputData[fieldNames[i]] =
                                          double.parse(controllers[i].text);
                                    }
                                  }
                                  Navigator.pop(context, inputData);
                                },
                                child: const Text('Lưu'),
                              )
                            ],
                          );
                        },
                      );
                      RuleConditionDevice conditionDevice = RuleConditionDevice(
                        option['name'].toString(),
                        deviceId,
                        newValue ?? {},
                      );
                      Navigator.pop(context, conditionDevice);
                    } else {
                      RuleConditionDevice conditionDevice = RuleConditionDevice(
                        option['name'].toString(),
                        deviceId,
                        option['value'],
                      );
                      Navigator.pop(context, conditionDevice);
                    }
                  },
                );
              },
            )
          : const Center(child: Text('No conditions available')),
    );
  }
}
