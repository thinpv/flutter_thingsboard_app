import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/device/lumi_plug_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class LumiPlugControlPage extends StatefulWidget {
  final TbContext tbContext;
  final LumiPlug lumiPlug;

  const LumiPlugControlPage(
    this.tbContext, {
    super.key,
    required this.lumiPlug,
  });

  @override
  State<LumiPlugControlPage> createState() => _LumiPlugControlPageState();
}

class _LumiPlugControlPageState extends State<LumiPlugControlPage> {
  bool isOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ổ cắm thông minh')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          GestureDetector(
            onTap: () {
              setState(() => isOn = !isOn);
              control();
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? Colors.green[300] : Colors.grey[300],
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isOn ? 'ON' : 'OFF',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isOn ? 'Đang bật' : 'Đang tắt',
            style: const TextStyle(fontSize: 18),
          ),
          const Spacer(),
          NavigationBar(
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.power), label: 'Nguồn điện'),
              NavigationDestination(
                  icon: Icon(Icons.schedule), label: 'Hẹn giờ'),
              NavigationDestination(icon: Icon(Icons.bolt), label: 'Điện năng'),
              NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Cài đặt'),
            ],
            selectedIndex: 0,
          ),
        ],
      ),
    );
  }

  Future<void> control() async {
    final rpcBody = {
      // 'method': 'control',
      // 'params': {
      //   'bt': isOn ? 1 : 0,
      // },
      'method': 'control_device',
      'params': {
        'id': widget.lumiPlug.name,
        'data': {
          'bt': isOn ? 1 : 0,
        },
      },
    };
    RequestConfig requestConfig = RequestConfig(
      ignoreLoading: true,
      ignoreErrors: true,
    );
    await widget.tbContext.tbClient
        .getDeviceService()
        .handleOneWayDeviceRPCRequest(
          // widget.lumiPlug.id!.id!,
          widget.lumiPlug.gatewayId!,
          rpcBody,
          requestConfig: requestConfig,
        );
  }
}
