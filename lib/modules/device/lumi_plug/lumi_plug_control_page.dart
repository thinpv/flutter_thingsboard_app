import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/device/lumi_plug_models.dart';

class LumiPlugControlPage extends StatefulWidget {
  final LumiPlug lumiPlug;

  const LumiPlugControlPage({super.key, required this.lumiPlug});

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
          GestureDetector(
            onTap: () => setState(() => isOn = !isOn),
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
                  )
                ],
              ),
              child: Center(
                child: Text(
                  isOn ? 'ON' : 'OFF',
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
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
          NavigationBar(destinations: const [
            NavigationDestination(icon: Icon(Icons.power), label: 'Nguồn điện'),
            NavigationDestination(icon: Icon(Icons.schedule), label: 'Hẹn giờ'),
            NavigationDestination(icon: Icon(Icons.bolt), label: 'Điện năng'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
          ], selectedIndex: 0),
        ],
      ),
    );
  }
}
