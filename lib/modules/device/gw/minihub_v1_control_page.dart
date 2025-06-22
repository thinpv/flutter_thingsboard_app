import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/device/gw/minihub_v1_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class MinihubV1ControlPage extends StatefulWidget {
  final TbContext tbContext;
  final MinihubV1 minihub;

  const MinihubV1ControlPage(this.tbContext,
      {super.key, required this.minihub});

  @override
  State<MinihubV1ControlPage> createState() => _MinihubV1ControlPageState();
}

class _MinihubV1ControlPageState extends State<MinihubV1ControlPage> {
  bool isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minihub')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          GestureDetector(
            onTap: () {
              setState(() => isScanning = !isScanning);
              final rpcBody = {
                'method': isScanning ? 'startScan' : 'stopScan',
                'params': {},
              };
              control(widget.minihub, rpcBody);
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isScanning ? Colors.red[300] : Colors.green[300],
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isScanning ? 'Dừng quét' : 'Tìm thiết bị',
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
            isScanning ? 'Đang tìm thiết bị' : '',
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

  Future<void> control(MinihubV1 minihub, Map<String, dynamic> rpcBody) async {
    RequestConfig requestConfig = RequestConfig(
      ignoreLoading: true,
      ignoreErrors: true,
    );
    await widget.tbContext.tbClient
        .getDeviceService()
        .handleOneWayDeviceRPCRequest(
          minihub.id!.id!,
          rpcBody,
          requestConfig: requestConfig,
        );
  }
}
