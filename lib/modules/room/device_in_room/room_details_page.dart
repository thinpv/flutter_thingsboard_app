import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'devices_in_room_list.dart';

class RoomDetailsPage extends TbContextWidget {
  final bool searchMode;
  final String roomId;

  RoomDetailsPage(
    TbContext tbContext,
    this.roomId, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends TbContextState<RoomDetailsPage> {
  final PageLinkController _pageLinkController = PageLinkController();
  bool lightOn = true;
  double brightness = 80;
  double cct = 4000;
  Color currentColor = Color(0xFFFFAA33);

  void pickColor() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chọn màu'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => setState(() => currentColor = color),
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          ElevatedButton(
            child: Text('Xong'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> sendConfig() async {
    final rpcBody = {
      'method': 'controlGroup',
      'params': {
        'id': widget.roomId,
        'data': {
          'onoff': lightOn ? 1 : 0,
          'brightness': brightness.toInt(),
          'cct': cct.toInt(),
          'color':
              '#${currentColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
        },
      },
    };

    AssetId assetId = AssetId(widget.roomId);
    final listRelation =
        await tbClient.getEntityRelationService().findInfoByFrom(assetId);

    List<String> deviceIds = [];
    for (final relation in listRelation) {
      final device =
          DeviceManager.instance.getMyDeviceInfoByName(relation.toName);
      if (device != null) {
        String deviceId = device.id!.id ?? '';
        if (device.gatewayId != null) deviceId = device.gatewayId!;
        if (!deviceIds.contains(deviceId) && (device.active ?? false)) {
          deviceIds.add(deviceId);
        }
      }
    }

    if (deviceIds.isNotEmpty) {
      for (final deviceId in deviceIds) {
        try {
          RequestConfig requestConfig = RequestConfig(
            ignoreLoading: true,
            ignoreErrors: true,
          );
          await tbClient.getDeviceService().handleOneWayDeviceRPCRequest(
                deviceId,
                rpcBody,
                requestConfig: requestConfig,
              );
        } catch (e) {
          print('Error sending RPC to device $deviceId: $e');
        }
      }
      // showSuccessSnackbar('Cấu hình đã được gửi thành công!');
    } else {
      // showErrorSnackbar('Không tìm thấy thiết bị trong phòng này.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomDetailsList = DevicesInRoomList(
      tbContext,
      _pageLinkController,
      widget.roomId,
      searchMode: widget.searchMode,
      displayDeviceImage: true,
    );
    PreferredSizeWidget appBar;
    if (widget.searchMode) {
      appBar = TbAppSearchBar(
        tbContext,
        onSearch: (searchText) => _pageLinkController.onSearchText(searchText),
      );
    } else {
      appBar = TbAppBar(
        tbContext,
        title: Text(roomDetailsList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/room/?id=${widget.roomId}&search=true');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              navigateTo('/room_add_device?id=${widget.roomId}');
            },
          ),
        ],
      );
    }
    return Scaffold(
      appBar: appBar,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đèn: ${lightOn ? 'Bật' : 'Tắt'}',
                    style: TextStyle(fontSize: 18)),
                Switch(
                  value: lightOn,
                  onChanged: (value) => setState(() => lightOn = value),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text('Độ sáng: ${brightness.toInt()}%',
                style: TextStyle(fontSize: 16)),
            Slider(
              min: 0,
              max: 100,
              divisions: 100,
              value: brightness,
              onChanged: (value) => setState(() => brightness = value),
            ),
            SizedBox(height: 20),
            Text('CCT: ${cct.toInt()}K', style: TextStyle(fontSize: 16)),
            Slider(
              min: 2700,
              max: 6500,
              divisions: 38,
              value: cct,
              onChanged: (value) => setState(() => cct = value),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text('Màu RGB:', style: TextStyle(fontSize: 16)),
                SizedBox(width: 12),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: pickColor,
                  child: Text('Chọn màu'),
                ),
              ],
            ),
            Spacer(),
            ElevatedButton.icon(
              icon: Icon(Icons.send),
              label: Text('Lưu cấu hình'),
              onPressed: sendConfig,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            Expanded(child: roomDetailsList),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
