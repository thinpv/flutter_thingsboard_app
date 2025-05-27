import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/scenario_models.dart';

class ThenPageSwitch2 extends StatelessWidget {
  final List<Option> options = [
    Option(name: 'Tắt nút số 1', value: '{"bt":0}'),
    Option(name: 'Bật nút số 1', value: '{"bt":1}'),
    Option(name: 'Tắt nút số 2', value: '{"bt2":0}'),
    Option(name: 'Bật nút số 2', value: '{"bt2":1}'),
  ];

  final SceneAction action;
  ThenPageSwitch2(this.action, {super.key});

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
              action.action = option.value;
              Navigator.pop(context, action);
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
