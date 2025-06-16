import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/provider/room_manager.dart';
import 'package:thingsboard_app/service/room_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'devices_in_room_list.dart';
import 'list_devices_page.dart';

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
  late Future<Room?> _roomFuture;
  final PageLinkController _pageLinkController = PageLinkController();
  bool lightOn = true;
  double brightness = 80;
  double cct = 4000;
  Color currentColor = const Color(0xFFFFAA33);

  @override
  void initState() {
    super.initState();
    _roomFuture = fetchEntity(widget.roomId);
  }

  Future<Room?> fetchEntity(String id) async {
    return RoomManager.instance.getRoomById(id);
  }

  void _refresh() {
    setState(() {
      _roomFuture = fetchEntity(widget.roomId);
    });
  }

  void pickColor() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chọn màu'),
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
            child: const Text('Xong'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> saveRoom(Room entity) async {
    RoomService.instance.saveRoom(entity);
  }

  Future<void> controlGroup() async {
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
    return FutureBuilder<Room?>(
      future: _roomFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Không tìm thấy ngữ cảnh')),
          );
        }
        return _buildEntityDetails(context, snapshot.data!);
      },
    );
  }

  Widget _buildEntityDetails(BuildContext context, Room entity) {
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
        title: Text(entity.getDisplayName()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/room/?id=${widget.roomId}&search=true');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push<Device>(
                context,
                MaterialPageRoute(builder: (context) => ListDevicesPage()),
              );
              if (result != null) {
                entity.addDevice(result.id!.id!);
                _refresh();
              }
            },
          ),
        ],
      );
    }
    return Scaffold(
      appBar: appBar,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildDevicesBlock(context, entity),
              const SizedBox(height: 16),
              _buildControlBlock(context, entity),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesBlock(BuildContext context, Room entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...entity.deviceIds.map((deviceId) {
            var myDeviceInfo =
                DeviceManager.instance.getMyDeviceInfoById(deviceId);
            var deviceTypeId = myDeviceInfo?.deviceProfileId?.id;
            var deviceType = deviceTypeId != null
                ? DeviceTypeManager.instance.getDeviceTypeById(deviceTypeId)
                : null;
            var hasImage = deviceType?.image != null;
            Widget image;
            if (hasImage) {
              image = Utils.imageFromTbImage(
                context,
                widget.tbContext.tbClient,
                deviceType?.image,
              );
            } else {
              image = const Icon(Icons.device_hub);
            }
            return ListTile(
              leading: image,
              title: Text(myDeviceInfo?.getDisplayName() ?? 'Unknown Device'),
              subtitle: Text(myDeviceInfo?.type ?? 'Unknown Type'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Xóa',
                onPressed: () {
                  entity.removeDevice(deviceId);
                  _refresh();
                },
              ),
            );
          }).toList(),
          _addButton(
            onPressed: () async {
              final result = await Navigator.push<Device>(
                context,
                MaterialPageRoute(builder: (context) => ListDevicesPage()),
              );
              if (result != null) {
                entity.addDevice(result.id!.id!);
                _refresh();
              }
            },
            tooltip: 'Thêm thiết bị',
          ),
        ],
      ),
    );
  }

  Widget _buildControlBlock(BuildContext context, Room entity) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đèn: ${lightOn ? 'Bật' : 'Tắt'}',
              style: const TextStyle(fontSize: 18),
            ),
            Switch(
              value: lightOn,
              onChanged: (value) {
                setState(() => lightOn = value);
                controlGroup();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Độ sáng: ${brightness.toInt()}%',
            style: const TextStyle(fontSize: 16)),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: brightness,
          onChanged: (value) => setState(() => brightness = value),
          onChangeEnd: (value) {
            setState(() => brightness = value);
            controlGroup();
          },
        ),
        const SizedBox(height: 20),
        Text('CCT: ${cct.toInt()}K', style: const TextStyle(fontSize: 16)),
        Slider(
          min: 2700,
          max: 6500,
          divisions: 38,
          value: cct,
          onChanged: (value) => setState(() => cct = value),
          onChangeEnd: (value) {
            setState(() => cct = value);
            controlGroup();
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Màu RGB:', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: pickColor,
              child: const Text('Chọn màu'),
            ),
          ],
        ),
        // Spacer(),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Lưu cấu hình'),
          onPressed: () => saveRoom(entity),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _addButton(
      {required VoidCallback onPressed, required String tooltip}) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: Icon(Icons.add_circle, color: Theme.of(context).primaryColor),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        const BoxShadow(
          color: Colors.black12,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
