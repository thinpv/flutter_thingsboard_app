import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/rule_models.dart';

import 'if_devices_page.dart';

class IfPage extends StatelessWidget {
  const IfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn loại đầu vào')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Thiết bị'),
            onTap: () async {
              final result = await Navigator.push<RuleConditionDevice>(
                context,
                MaterialPageRoute(builder: (context) => const IfDevicesPage()),
              );
              Navigator.pop(context, result);
            },
          ),
        ],
      ),
    );
  }
}
