import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/scenario_models.dart';

class IfPageSwitch2 extends StatelessWidget {
  final List<Option> options = [
    Option(name: 'Nút số 1 tắt', value: '{"bt":0, "op":"=="}'),
    Option(name: 'Nút số 1 bật', value: '{"bt":1, "op":"=="}'),
    Option(name: 'Nút số 2 tắt', value: '{"bt2":0, "op":"=="}'),
    Option(name: 'Nút số 2 bật', value: '{"bt2":1, "op":"=="}'),
  ];

  final SceneCondition condition;
  IfPageSwitch2(this.condition, {super.key});

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
              condition.condition = option.value;
              Navigator.pop(context, condition);
            },
          );
        },
      ),
    );
  }
}

class Option {
  final String name;
  final String value;

  Option({required this.name, required this.value});
}
