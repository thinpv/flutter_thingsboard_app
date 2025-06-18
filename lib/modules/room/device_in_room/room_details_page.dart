import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/provider/room_manager.dart';
import 'package:thingsboard_app/service/room_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'list_devices_multi_page.dart';
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
  bool onoff = true;
  double dim = 100;
  double cct = 100;
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
    entity.updateGatewayList();
    Map<String, List<DeviceInRoom>> deviceInRoomList = {};
    for (final deviceInRoom in entity.deviceInRooms) {
      final device =
          DeviceManager.instance.getMyDeviceInfoById(deviceInRoom.deviceId);
      if (device != null) {
        if (device.gatewayId != null) {
          deviceInRoomList[device.gatewayId!] ??= [];
          deviceInRoomList[device.gatewayId!]!.add(deviceInRoom);
        }
        if (device.isGateway) {
          deviceInRoomList[deviceInRoom.deviceId] ??= [];
          deviceInRoomList[deviceInRoom.deviceId]!.add(deviceInRoom);
        }
      }
    }

    deviceInRoomList.forEach((gatewayId, deviceInRooms) async {
      List<dynamic> devicesInfo = [];
      for (final deviceInRoom in deviceInRooms) {
        devicesInfo.add(deviceInRoom.buildRoom());
      }
      final groupData = {
        'name': entity.getDisplayName(),
        'devices': devicesInfo,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      try {
        Map<String, dynamic> groups = {};
        final groupsReq =
            await tbClient.getAttributeService().getAttributesByScope(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          ['groups'],
        );
        if (groupsReq.isNotEmpty) {
          final value = groupsReq.first.getValue();
          if (value is String) {
            groups = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            groups = value;
          }
        }
        groups[widget.roomId] = groupData;
        await tbClient.getAttributeService().saveEntityAttributesV1(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          {'groups': groups},
        );
      } catch (e) {
        print('Error saving attributes for gateway $gatewayId: $e');
      }
    });

    RoomService.instance.saveRoom(entity);
  }

  Future<void> deleteRoom(Room room) async {
    room.updateGatewayList();
    for (String gatewayId in room.gatewayIds) {
      try {
        Map<String, dynamic> groups = {};
        final groupsReq =
            await tbClient.getAttributeService().getAttributesByScope(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          ['groups'],
        );
        if (groupsReq.isNotEmpty) {
          final value = groupsReq.first.getValue();
          if (value is String) {
            groups = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            groups = value;
          }
        }
        groups.remove(widget.roomId);
        await tbClient.getAttributeService().saveEntityAttributesV1(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          {'groups': groups},
        );
      } catch (e) {
        print('Error saving attributes for gateway $gatewayId: $e');
      }
    }
    RoomManager.instance.deleteRoom(room);
    Navigator.pop(context);
  }

  Future<void> controlGroup(Room entity, Map<String, dynamic> data) async {
    final rpcBody = {
      'method': 'controlGroup',
      'params': {
        'id': widget.roomId,
        'data': data,
      },
    };

    for (final deviceId in entity.gatewayIds) {
      try {
        MyDeviceInfo? deviceInfo =
            DeviceManager.instance.getMyDeviceInfoById(deviceId);
        if (deviceInfo != null && deviceInfo.active == true) {
          RequestConfig requestConfig = RequestConfig(
            ignoreLoading: true,
            ignoreErrors: true,
          );
          await tbClient.getDeviceService().handleOneWayDeviceRPCRequest(
                deviceId,
                rpcBody,
                requestConfig: requestConfig,
              );
        }
      } catch (e) {
        print('Error sending RPC to device $deviceId: $e');
      }
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
    PreferredSizeWidget appBar;
    if (widget.searchMode) {
      appBar = TbAppSearchBar(
        tbContext,
        onSearch: (searchText) => _pageLinkController.onSearchText(searchText),
      );
    } else {
      appBar = AppBar(
        title: GestureDetector(
          onTap: () async {
            final controller =
                TextEditingController(text: entity.getDisplayName());
            final newName = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cập nhật tên ngữ cảnh'),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Tên ngữ cảnh',
                  ),
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: Text(S.of(context).save),
                  ),
                ],
              ),
            );
            if (newName != null &&
                newName.trim().isNotEmpty &&
                newName != entity.label) {
              entity.label = newName.trim();
              _refresh();
            }
          },
          child: Text(entity.getDisplayName()),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
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
              _buildControlBlock(context, entity),
              const SizedBox(height: 16),
              _buildDevicesBlock(context, entity),
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
          ...entity.deviceInRooms.map((deviceInRoom) {
            var myDeviceInfo = DeviceManager.instance
                .getMyDeviceInfoById(deviceInRoom.deviceId);
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
                  entity.removeDeviceInRoom(deviceInRoom);
                  _refresh();
                },
              ),
            );
          }).toList(),
          _addButton(
            onPressed: () async {
              final result = await Navigator.push<DeviceInRoom>(
                context,
                MaterialPageRoute(
                    builder: (context) => const ListDevicesPage()),
              );
              if (result != null) {
                entity.addDeviceInRoom(result);
                _refresh();
              }

              // final deviceInRooms = await Navigator.push<List<DeviceInRoom>>(
              //   context,
              //   MaterialPageRoute(
              //       builder: (context) => const ListDevicesMultiPage()),
              // );
              // if (deviceInRooms != null) {
              //   for (DeviceInRoom deviceInRoom in deviceInRooms) {
              //     entity.addDeviceInRoom(deviceInRoom);
              //   }
              //   _refresh();
              // }
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
              'Đèn: ${onoff ? 'Bật' : 'Tắt'}',
              style: const TextStyle(fontSize: 18),
            ),
            Switch(
              value: onoff,
              onChanged: (value) {
                setState(() => onoff = value);
                controlGroup(entity, {
                  'onoff': onoff ? 1 : 0,
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Độ sáng: ${dim.toInt()}%',
          style: const TextStyle(fontSize: 16),
        ),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: dim,
          onChanged: (value) => setState(() => dim = value),
          onChangeEnd: (value) {
            setState(() => dim = value);
            setState(() => onoff = dim > 0);
            controlGroup(entity, {
              'dim': dim.toInt(),
            });
          },
        ),
        const SizedBox(height: 20),
        Text('CCT: ${cct.toInt() * 38 + 2700}K',
            style: const TextStyle(fontSize: 16)),
        Slider(
          min: 0,
          max: 100,
          divisions: 38,
          value: cct,
          onChanged: (value) => setState(() => cct = value),
          onChangeEnd: (value) {
            setState(() => cct = value);
            controlGroup(entity, {
              'cct': cct.toInt(),
            });
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
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete),
          label: const Text('Xóa phòng'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Xác nhận'),
                content: const Text('Bạn có chắc chắn muốn tiếp tục?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false), // Cancel
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true), // OK
                    child: const Text('Đồng ý'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              deleteRoom(entity);
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _addButton({
    required VoidCallback onPressed,
    required String tooltip,
  }) {
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
      boxShadow: const [
        BoxShadow(
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
