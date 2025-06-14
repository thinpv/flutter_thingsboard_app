import 'package:flutter/material.dart';

class PowerUsagePage extends StatelessWidget {
  final double voltage = 213.2;
  final double powerToday = 0.08;
  final double totalPower = 0.14;

  const PowerUsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Điện năng tiêu thụ')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$powerToday', style: const TextStyle(fontSize: 48)),
          const Text('Công suất tiêu thụ hôm nay (kWh)'),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _infoTile('Dòng điện', '0 mA'),
              _infoTile('Điện năng', '$powerToday kWh'),
              _infoTile('Điện áp', '$voltage V'),
              _infoTile('Tổng', '$totalPower kWh'),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField(
              items: const [
                DropdownMenuItem(value: '3', child: Text('Tháng 3')),
              ],
              value: '3',
              onChanged: (_) {},
              decoration: const InputDecoration(labelText: 'Chọn tháng'),
            ),
          )
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
