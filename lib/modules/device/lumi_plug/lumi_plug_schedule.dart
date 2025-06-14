import 'package:flutter/material.dart';

class TaskSchedulePage extends StatefulWidget {
  const TaskSchedulePage({super.key});

  @override
  _TaskSchedulePageState createState() => _TaskSchedulePageState();
}

class _TaskSchedulePageState extends State<TaskSchedulePage> {
  List<Map<String, dynamic>> tasks = [
    {
      'time': '16:33',
      'days': ['Thứ 3', 'Thứ 4', 'Thứ 5'],
      'action': 'Bật',
      'enabled': true
    },
    {
      'time': '19:40',
      'days': ['Thứ 3', 'Thứ 4', 'Thứ 5'],
      'action': 'Tắt',
      'enabled': true
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhiệm vụ')),
      body: ListView(
        children: [
          for (var task in tasks)
            ListTile(
              title: Text('${task['time']}'),
              subtitle: Text(
                  '${task['days'].join(' ')} - Công tắc 1: ${task['action']}'),
              trailing: Switch(
                value: task['enabled'],
                onChanged: (val) {
                  setState(() => task['enabled'] = val);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhiệm vụ'),
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }
}
