import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device/lumi_plug_models.dart';

class LumiPlugWidget extends StatelessWidget {
  final LumiPlug lumiPlug;
  const LumiPlugWidget({super.key, required this.lumiPlug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lumiPlug.getDisplayName())),
      body: ListTile(
        title: Text(lumiPlug.getDisplayName()),
        subtitle: Text('Điều khiển đèn: ${lumiPlug.toString()}'),
      ),
    );
  }
}
