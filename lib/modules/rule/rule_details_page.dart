import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/provider/room_manager.dart';
import 'package:thingsboard_app/provider/rule_manager.dart';
import 'package:thingsboard_app/service/rule_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'if/if_page.dart';
import 'then/then_page.dart';

class RuleDetailsPage extends StatefulWidget {
  final TbContext tbContext;
  final String ruleId;

  const RuleDetailsPage(this.tbContext, this.ruleId, {super.key});

  @override
  State<RuleDetailsPage> createState() => _RuleDetailsPageState();
}

class _RuleDetailsPageState extends State<RuleDetailsPage> {
  late Future<Rule?> _ruleFuture;

  @override
  void initState() {
    super.initState();
    _ruleFuture = fetchEntity(widget.ruleId);
  }

  Future<Rule?> fetchEntity(String id) async {
    return RuleManager.instance.getRuleById(id);
  }

  void _refresh() {
    setState(() {
      _ruleFuture = fetchEntity(widget.ruleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Rule?>(
      future: _ruleFuture,
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

  Widget _buildEntityDetails(BuildContext context, Rule entity) {
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

  Widget _buildIfBlock(BuildContext context, Rule entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            S.of(context).if_,
            'Khi bất kỳ điều kiện nào được đáp ứng',
          ),
          ...entity.ifConditions
              .map((condition) {
                if (condition is RuleConditionDevice) {
                  var myDeviceInfo = DeviceManager.instance
                      .getMyDeviceInfoById(condition.deviceId);
                  var deviceTypeId = myDeviceInfo?.deviceProfileId?.id;
                  var deviceType = deviceTypeId != null
                      ? DeviceTypeManager.instance
                          .getDeviceTypeById(deviceTypeId)
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
                    title: Text(
                      myDeviceInfo?.getDisplayName() ?? 'Unknown Device',
                    ),
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
              })
              .whereType<Widget>()
              .toList(),
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

  Widget _buildThenBlock(BuildContext context, Rule entity) {
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

  Widget _buildPreconditionDisplayArea(Rule entity) {
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

  Widget _buildSaveButton(BuildContext context, Rule entity) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text('Lưu cấu hình'),
          onPressed: () => saveRule(entity),
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
              deleteRule(entity);
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

  Future<void> saveRule(Rule rule) async {
    String? oldGatewayId = rule.gatewayId;
    String? gatewayId = rule.calculateDeviceSave();
    if (gatewayId != null) {
      try {
        Map<String, dynamic> rules = {};
        final rulesReq = await widget.tbContext.tbClient
            .getAttributeService()
            .getAttributesByScope(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          ['rules'],
        );
        if (rulesReq.isNotEmpty) {
          final value = rulesReq.first.getValue();
          if (value is String) {
            rules = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            rules = value;
          }
        }
        rules[widget.ruleId] = rule.buildRule();
        await widget.tbContext.tbClient
            .getAttributeService()
            .saveEntityAttributesV1(
          DeviceId(gatewayId),
          'SHARED_SCOPE',
          {'rules': rules},
        );
      } catch (e) {
        print('Error saving attributes for gateway $gatewayId: $e');
      }
    } else if (oldGatewayId != null) {
      // Remove the rule from the old gateway if it exists
      try {
        Map<String, dynamic> rules = {};
        final rulesReq = await widget.tbContext.tbClient
            .getAttributeService()
            .getAttributesByScope(
          DeviceId(oldGatewayId),
          'SHARED_SCOPE',
          ['rules'],
        );
        if (rulesReq.isNotEmpty) {
          final value = rulesReq.first.getValue();
          if (value is String) {
            rules = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            rules = value;
          }
        }
        rules.remove(widget.ruleId);
        await widget.tbContext.tbClient
            .getAttributeService()
            .saveEntityAttributesV1(
          DeviceId(oldGatewayId),
          'SHARED_SCOPE',
          {'rules': rules},
        );
      } catch (e) {
        print('Error saving attributes for gateway $oldGatewayId: $e');
      }
    }
    await RuleService.instance.saveRule(rule);
    _refresh();
  }

  Future<void> deleteRule(Rule rule) async {
    if (rule.gatewayId != null) {
      try {
        Map<String, dynamic> rules = {};
        final rulesReq = await widget.tbContext.tbClient
            .getAttributeService()
            .getAttributesByScope(
          DeviceId(rule.gatewayId!),
          'SHARED_SCOPE',
          ['rules'],
        );
        if (rulesReq.isNotEmpty) {
          final value = rulesReq.first.getValue();
          if (value is String) {
            rules = jsonDecode(value) as Map<String, dynamic>;
          } else if (value is Map<String, dynamic>) {
            rules = value;
          }
        }
        rules.remove(widget.ruleId);
        await widget.tbContext.tbClient
            .getAttributeService()
            .saveEntityAttributesV1(
          DeviceId(rule.gatewayId!),
          'SHARED_SCOPE',
          {'rules': rules},
        );
      } catch (e) {
        print('Error saving attributes for gateway $rule.gatewayId!: $e');
      }
    }
    await RuleService.instance.deleteRule(widget.ruleId);
    Navigator.pop(context);
  }
}
