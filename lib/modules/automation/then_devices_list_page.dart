import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/modules/automation/then_devices_list.dart';
import 'package:thingsboard_app/modules/device/devices_base.dart';

class ThenDevicesListPage extends TbContextWidget {
  final String? deviceType;
  final bool? active;
  final bool searchMode;

  ThenDevicesListPage(
    TbContext tbContext, {
    this.deviceType,
    this.active,
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _DevicesListPageState();
}

class _DevicesListPageState extends TbContextState<ThenDevicesListPage>
    with AutomaticKeepAliveClientMixin<ThenDevicesListPage> {
  late final DeviceQueryController _deviceQueryController;

  @override
  void initState() {
    super.initState();
    _deviceQueryController = DeviceQueryController(
      deviceType: widget.deviceType,
      active: widget.active,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var thenDevicesList = ThenDevicesList(
      tbContext,
      _deviceQueryController,
      searchMode: widget.searchMode,
      displayDeviceImage: widget.deviceType == null,
    );
    return Scaffold(
      appBar: AppBar(title: Text('Chọn thiết bị')),
      body: thenDevicesList,
    );
  }

  @override
  void dispose() {
    _deviceQueryController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
