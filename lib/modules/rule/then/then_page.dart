import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/model/rule_models.dart';

import 'then_devices_page.dart';
import 'then_rooms_page.dart';

class ThenPage extends StatelessWidget {
  const ThenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn loại đầu ra')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Thiết bị'),
            onTap: () async {
              final result = await Navigator.push<RuleActionDevice>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThenDevicesPage(),
                ),
              );
              Navigator.pop(context, result);
            },
          ),
          ListTile(
            title: const Text('Phòng'),
            onTap: () async {
              final result = await Navigator.push<RuleActionRoom>(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThenRoomsPage(),
                ),
              );
              Navigator.pop(context, result);
            },
          ),
          ListTile(
            title: const Text('Trễ'),
            onTap: () async {
              final controller = TextEditingController();
              final result = await showDialog<RuleActionDelay>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cài đặt thời gian trễ'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian trễ (giây)',
                    ),
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        RuleActionDelay(
                            'Trễ', int.tryParse(controller.text) ?? 0),
                      ),
                      child: Text(S.of(context).save),
                    ),
                  ],
                ),
              );
              Navigator.pop(context, result);
            },
          ),
        ],
      ),
    );
  }
}
