import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/provider/room_manager.dart';
import 'package:thingsboard_app/service/rule_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'if/if_page.dart';
import 'then/then_page.dart';

class RuleAddPage extends StatefulWidget {
  final TbContext tbContext;

  const RuleAddPage(this.tbContext, {super.key});

  @override
  State<RuleAddPage> createState() => _RuleAddPageState();
}

class _RuleAddPageState extends State<RuleAddPage> {
  late Future<RuleAdd?> _ruleAddFuture;
  late RuleAdd ruleAdd;

  @override
  void initState() {
    super.initState();
    ruleAdd = RuleAdd();
    _ruleAddFuture = fetchEntity();
  }

  Future<RuleAdd?> fetchEntity() async {
    return Future.value(ruleAdd);
  }

  void _refresh() {
    setState(() {
      _ruleAddFuture = fetchEntity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RuleAdd?>(
      future: _ruleAddFuture,
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

  Widget _buildEntityDetails(BuildContext context, RuleAdd entity) {
    return Scaffold(
      appBar: AppBar(
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

  Widget _buildIfBlock(BuildContext context, RuleAdd entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            S.of(context).if_,
            'Khi bất kỳ điều kiện nào được đáp ứng',
          ),
          ...entity.ifConditions.map((condition) {
            if (condition is RuleConditionDevice) {
              var myDeviceInfo = DeviceManager.instance
                  .getMyDeviceInfoById(condition.deviceId);
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
                subtitle: Text(condition.description ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Xóa',
                  onPressed: () {
                    entity.ifConditions.remove(condition);
                    _refresh();
                  },
                ),
              );
            } else {
              return null;
            }
          }).whereType<Widget>(),
          _addButton(
            onPressed: () async {
              final result = await Navigator.push<RuleCondition>(
                context,
                MaterialPageRoute(builder: (context) => const IfPage()),
              );
              if (result != null) {
                entity.ifConditions.add(result);
                _refresh();
              }
            },
            tooltip: 'Thêm điều kiện',
          ),
        ],
      ),
    );
  }

  Widget _buildThenBlock(BuildContext context, RuleAdd entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(S.of(context).then, 'Thêm tác vụ khi điều kiện đúng'),
          ...entity.thenActions.map((action) {
            if (action is RuleActionDevice) {
              var myDeviceInfo =
                  DeviceManager.instance.getMyDeviceInfoById(action.deviceId);
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
                subtitle: Text(action.description ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Xóa',
                  onPressed: () {
                    entity.thenActions.remove(action);
                    _refresh();
                  },
                ),
              );
            } else if (action is RuleActionRoom) {
              RoomInfo? roomInfo =
                  RoomManager.instance.getRoomById(action.roomId);
              return ListTile(
                leading: const Icon(Icons.meeting_room),
                title: Text(roomInfo?.getDisplayName() ?? 'Unknown Room'),
                subtitle: Text(action.description ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Xóa',
                  onPressed: () {
                    entity.thenActions.remove(action);
                    _refresh();
                  },
                ),
              );
            } else if (action is RuleActionDelay) {
              return ListTile(
                leading: const Icon(Icons.timer),
                title: Text('Trễ ${action.delay} giây'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Xóa',
                  onPressed: () {
                    entity.thenActions.remove(action);
                    _refresh();
                  },
                ),
              );
            } else {
              return null;
            }
          }).whereType<Widget>(),
          _addButton(
            onPressed: () async {
              final result = await Navigator.push<RuleAction>(
                context,
                MaterialPageRoute(builder: (context) => const ThenPage()),
              );
              if (result != null) {
                entity.thenActions.add(result);
                _refresh();
              }
            },
            tooltip: 'Thêm tác vụ',
          ),
        ],
      ),
    );
  }

  Widget _buildPreconditionDisplayArea(RuleAdd entity) {
    return const Column(
      children: [
        ListTile(
          title: Text('Precondition'),
          trailing: Text('Cả ngày'),
        ),
        ListTile(
          title: Text('Display Area'),
          trailing: Icon(Icons.arrow_forward_ios),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, RuleAdd entity) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final customerId =
              widget.tbContext.tbClient.getAuthUser()?.customerId;
          if (customerId != null) {
            entity.customerId = CustomerId(customerId);
            // entity.calculateDeviceSave();
            print('----------- entity: ${entity.toJson()}');
            await RuleService.instance.saveRule(entity);
            _refresh();
          } else {
            // Handle the case when customerId is null, e.g., show an error
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Customer ID is not available.')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(S.of(context).save, style: const TextStyle(fontSize: 16)),
      ),
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

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
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
}
