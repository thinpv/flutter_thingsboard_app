import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thingsboard_app/model/rule_models.dart';

class ThenRoomActionsPage extends StatelessWidget {
  final List<Option> options = [
    Option(name: 'Tắt phòng', value: {'onoff': 0}),
    Option(name: 'Bật phòng', value: {'onoff': 1}),
    Option(name: 'Bật/Tắt phòng', value: {'onoff': 2}),
    Option(name: 'Điều chỉnh độ sáng', value: {'dim': '?number'}),
    Option(name: 'Điều chỉnh CCT', value: {'cct': '?number'}),
  ];
  String roomId;

  ThenRoomActionsPage(this.roomId, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chọn thuộc tính')),
      body: ListView.builder(
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            title: Text(option.name),
            onTap: () async {
              final values = option.value;
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
                          children: List.generate(fieldNames.length, (index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: TextField(
                                controller: controllers[index],
                                decoration: InputDecoration(
                                  labelText: fieldNames[index],
                                ),
                                keyboardType:
                                    values[fieldNames[index]].toLowerCase() ==
                                            '?number'
                                        ? TextInputType.number
                                        : TextInputType.text,
                                inputFormatters:
                                    values[fieldNames[index]].toLowerCase() ==
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
                                inputData[fieldNames[i]] = controllers[i].text;
                              } else if (dataType.toLowerCase() == '?number') {
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
                RuleActionRoom actionRoom = RuleActionRoom(
                  option.name,
                  roomId,
                  newValue ?? {},
                );
                Navigator.pop(context, actionRoom);
              } else {
                RuleActionRoom actionRoom = RuleActionRoom(
                  option.name,
                  roomId,
                  option.value,
                );
                Navigator.pop(context, actionRoom);
              }
            },
          );
        },
      ),
    );
  }
}

class Option {
  final String name;
  final Map<String, dynamic> value;

  Option({required this.name, required this.value});
}
