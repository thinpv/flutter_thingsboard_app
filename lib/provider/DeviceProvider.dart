import 'package:flutter/material.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class DeviceProvider extends ChangeNotifier {
  final ThingsboardClient tbClient;
  List<DeviceInfo> _devices = [];
  bool _loading = false;

  DeviceProvider(this.tbClient);

  List<DeviceInfo> get devices => _devices;
  bool get loading => _loading;

  Future<void> loadDevices({bool force = false}) async {
    if (_devices.isNotEmpty && !force) return;
    _loading = true;
    notifyListeners();

    final user = await tbClient.getUserService().getUser();
    final page = await tbClient
        .getDeviceService()
        .getCustomerDeviceInfos(user.customerId!.id!, PageLink(100));
    _devices = page.data;
    _loading = false;
    notifyListeners();
  }
}
