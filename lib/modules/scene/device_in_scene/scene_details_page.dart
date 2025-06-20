import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/provider/scene_manager.dart';
import 'package:thingsboard_app/service/scene_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'list_devices_multi_page.dart';
import 'list_devices_page.dart';

class SceneDetailsPage extends TbContextWidget {
  final bool searchMode;
  final String sceneId;

  SceneDetailsPage(
    TbContext tbContext,
    this.sceneId, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _SceneDetailsPageState();
}

class _SceneDetailsPageState extends TbContextState<SceneDetailsPage> {
  late Future<Scene?> _sceneFuture;
  final PageLinkController _pageLinkController = PageLinkController();
  bool onoff = true;
  double dim = 100;
  double cct = 100;
  Color currentColor = const Color(0xFFFFAA33);

  @override
  void initState() {
    super.initState();
    _sceneFuture = fetchEntity(widget.sceneId);
  }

  Future<Scene?> fetchEntity(String id) async {
    return SceneManager.instance.getSceneById(id);
  }

  void _refresh() {
    setState(() {
      _sceneFuture = fetchEntity(widget.sceneId);
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

  Future<void> saveScene(Scene entity) async {
    entity.updateGatewayList();
    Map<String, List<DeviceInScene>> deviceInSceneList = {};
    for (final deviceInScene in entity.deviceInScenes) {
      final device =
          DeviceManager.instance.getMyDeviceInfoById(deviceInScene.deviceId);
      if (device != null) {
        if (device.gatewayId != null) {
          deviceInSceneList[device.gatewayId!] ??= [];
          deviceInSceneList[device.gatewayId!]!.add(deviceInScene);
        }
        if (device.isGateway) {
          deviceInSceneList[deviceInScene.deviceId] ??= [];
          deviceInSceneList[deviceInScene.deviceId]!.add(deviceInScene);
        }
      }
    }

    deviceInSceneList.forEach((gatewayId, deviceInScenes) async {
      List<dynamic> devicesInfo = [];
      for (final deviceInScene in deviceInScenes) {
        devicesInfo.add(deviceInScene.buildScene());
      }
      final sceneData = {
        'name': entity.getDisplayName(),
        'devices': devicesInfo,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      try {
        Map<String, dynamic> scenes = {};
        final scenesReq =
            await tbClient.getAttributeService().getAttributesByScope(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          ['scenes'],
        );
        if (scenesReq.isNotEmpty) {
          final value = scenesReq.first.getValue();
          if (value is String) {
            scenes = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            scenes = value;
          }
        }
        scenes[widget.sceneId] = sceneData;
        await tbClient.getAttributeService().saveEntityAttributesV1(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          {'scenes': scenes},
        );
      } catch (e) {
        print('Error saving attributes for gateway $gatewayId: $e');
      }
    });

    SceneService.instance.saveScene(entity);
  }

  Future<void> deleteScene(Scene scene) async {
    scene.updateGatewayList();
    for (String gatewayId in scene.gatewayIds) {
      try {
        Map<String, dynamic> scenes = {};
        final scenesReq =
            await tbClient.getAttributeService().getAttributesByScope(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          ['scenes'],
        );
        if (scenesReq.isNotEmpty) {
          final value = scenesReq.first.getValue();
          if (value is String) {
            scenes = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            scenes = value;
          }
        }
        scenes.remove(widget.sceneId);
        await tbClient.getAttributeService().saveEntityAttributesV1(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          {'scenes': scenes},
        );
      } catch (e) {
        print('Error saving attributes for gateway $gatewayId: $e');
      }
    }
    SceneManager.instance.deleteScene(scene);
    Navigator.pop(context);
  }

  Future<void> activeScene(Scene entity) async {
    final rpcBody = {
      'method': 'activeScene',
      'params': {
        'id': widget.sceneId,
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
    return FutureBuilder<Scene?>(
      future: _sceneFuture,
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

  Widget _buildEntityDetails(BuildContext context, Scene entity) {
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

  Widget _buildDevicesBlock(BuildContext context, Scene entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...entity.deviceInScenes.map((deviceInScene) {
            var myDeviceInfo = DeviceManager.instance
                .getMyDeviceInfoById(deviceInScene.deviceId);
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
                  entity.removeDeviceInScene(deviceInScene);
                  _refresh();
                },
              ),
            );
          }).toList(),
          _addButton(
            onPressed: () async {
              final result = await Navigator.push<DeviceInScene>(
                context,
                MaterialPageRoute(
                    builder: (context) => const ListDevicesPage()),
              );
              if (result != null) {
                entity.addDeviceInScene(result);
                _refresh();
              }

              // final deviceInScenes = await Navigator.push<List<DeviceInScene>>(
              //   context,
              //   MaterialPageRoute(
              //       builder: (context) => const ListDevicesMultiPage()),
              // );
              // if (deviceInScenes != null) {
              //   for (DeviceInScene deviceInScene in deviceInScenes) {
              //     entity.addDeviceInScene(deviceInScene);
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

  Widget _buildControlBlock(BuildContext context, Scene entity) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Kích hoạt kịch bản'),
          onPressed: () => activeScene(entity),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Lưu cấu hình'),
          onPressed: () => saveScene(entity),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete),
          label: const Text('Xóa kịch bản'),
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
              deleteScene(entity);
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
