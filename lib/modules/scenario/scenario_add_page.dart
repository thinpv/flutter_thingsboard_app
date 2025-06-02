import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/service/scenario_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'if/if_devices_page.dart';
import 'then/then_devices_page.dart';

class ScenarioAddPage extends StatefulWidget {
  final TbContext tbContext;

  ScenarioAddPage(this.tbContext, {super.key});

  @override
  State<ScenarioAddPage> createState() => _ScenarioAddPageState();
}

class _ScenarioAddPageState extends State<ScenarioAddPage> {
  late Future<ScenarioAdd?> _scenarioAddFuture;
  late ScenarioAdd scenarioAdd;

  @override
  void initState() {
    super.initState();
    scenarioAdd = ScenarioAdd('Ten mac dinh');
    _scenarioAddFuture = fetchEntity();
  }

  Future<ScenarioAdd?> fetchEntity() async {
    return Future.value(scenarioAdd);
  }

  void _refresh() {
    setState(() {
      _scenarioAddFuture = fetchEntity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScenarioAdd?>(
      future: _scenarioAddFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
              body: Center(child: Text('Không tìm thấy ngữ cảnh')));
        }
        return _buildEntityDetails(context, snapshot.data!);
      },
    );
  }

  Widget _buildEntityDetails(BuildContext context, ScenarioAdd entity) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            final controller = TextEditingController(text: entity.displayName);
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
                newName != entity.displayName) {
              entity.displayName = newName.trim();
              _refresh();
            }
          },
          child: Text(entity.displayName ?? entity.name),
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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildIfBlock(context, entity),
              const SizedBox(height: 16),
              _buildThenBlock(context, entity),
              const SizedBox(height: 16),
              _buildPreconditionDisplayArea(entity),
              _buildSaveButton(context, entity),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIfBlock(BuildContext context, ScenarioAdd entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              S.of(context).if_, 'Khi bất kỳ điều kiện nào được đáp ứng'),
          ...entity.smartScene.ifConditions.map((condition) {
            var myDeviceInfo =
                DeviceManager.instance.getMyDeviceInfoById(condition.device);
            var deviceTypeId = myDeviceInfo?.deviceProfileId?.id;
            var deviceType = deviceTypeId != null
                ? DeviceTypeManager.instance.getDeviceTypeById(deviceTypeId)
                : null;
            var hasImage = deviceType?.image != null;
            Widget image;
            if (hasImage) {
              image = Utils.imageFromTbImage(
                  context, widget.tbContext.tbClient, deviceType?.image);
            } else {
              image = Icon(Icons.device_hub);
            }
            return ListTile(
              leading: image,
              title: Text(myDeviceInfo?.displayName ??
                  myDeviceInfo?.name ??
                  'Unknown Device'),
              subtitle: Text(condition.condition),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Xóa',
                onPressed: () {
                  entity.smartScene.ifConditions.remove(condition);
                  // entity.update(ifConditions: entity.smartScene.ifConditions);
                  _refresh();
                },
              ),
            );
          }).toList(),
          _addButton(
              onPressed: () async {
                final result = await Navigator.push<SceneCondition>(
                  context,
                  MaterialPageRoute(builder: (context) => IfDevicesPage()),
                );
                if (result != null) {
                  entity.smartScene.ifConditions.add(result);
                  // entity.update(ifConditions: entity.smartScene.ifConditions);
                  _refresh();
                }
              },
              tooltip: 'Thêm điều kiện'),
        ],
      ),
    );
  }

  Widget _buildThenBlock(BuildContext context, ScenarioAdd entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(S.of(context).then, 'Thêm tác vụ khi điều kiện đúng'),
          ...entity.smartScene.thenActions.map((action) {
            var myDeviceInfo =
                DeviceManager.instance.getMyDeviceInfoById(action.device);
            var deviceTypeId = myDeviceInfo?.deviceProfileId?.id;
            var deviceType = deviceTypeId != null
                ? DeviceTypeManager.instance.getDeviceTypeById(deviceTypeId)
                : null;
            var hasImage = deviceType?.image != null;
            Widget image;
            if (hasImage) {
              image = Utils.imageFromTbImage(
                  context, widget.tbContext.tbClient, deviceType?.image);
            } else {
              image = Icon(Icons.device_hub);
            }
            return ListTile(
              leading: image,
              title: Text(myDeviceInfo?.displayName ??
                  myDeviceInfo?.name ??
                  'Unknown Device'),
              subtitle: Text(action.action),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Xóa',
                onPressed: () {
                  entity.smartScene.thenActions.remove(action);
                  // entity.update(thenActions: entity.smartScene.thenActions);
                  _refresh();
                },
              ),
            );
          }).toList(),
          _addButton(
              onPressed: () async {
                final result = await Navigator.push<SceneAction>(
                  context,
                  MaterialPageRoute(builder: (context) => ThenDevicesPage()),
                );
                if (result != null) {
                  entity.smartScene.thenActions.add(result);
                  // entity.update(thenActions: entity.smartScene.thenActions);
                  _refresh();
                }
              },
              tooltip: 'Thêm tác vụ'),
        ],
      ),
    );
  }

  Widget _buildPreconditionDisplayArea(ScenarioAdd entity) {
    return Column(
      children: [
        ListTile(
          title: const Text('Precondition'),
          trailing: const Text('Cả ngày'),
        ),
        ListTile(
          title: const Text('Display Area'),
          trailing: const Icon(Icons.arrow_forward_ios),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, ScenarioAdd entity) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final customerId =
              widget.tbContext.tbClient.getAuthUser()?.customerId;
          if (customerId != null) {
            entity.customerId = CustomerId(customerId);
            entity.smartScene.calculateDeviceSave();
            await ScenarioService.instance.saveScenario(entity);
            _refresh();
          } else {
            // Handle the case when customerId is null, e.g., show an error
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Customer ID is not available.')));
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(S.of(context).save, style: TextStyle(fontSize: 16)),
      ),
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

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        const BoxShadow(
            color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }
}
