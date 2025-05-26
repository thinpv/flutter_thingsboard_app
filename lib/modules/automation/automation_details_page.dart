import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entity_details_page.dart';
import 'package:thingsboard_app/model/automation_models.dart';
import 'package:thingsboard_app/modules/automation/if/if_devices_page.dart';
import 'package:thingsboard_app/modules/automation/then_devices_list_page.dart';
import 'package:thingsboard_app/provider/DeviceManager.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class AutomationDetailsPage extends EntityDetailsPage<Automation> {
  AutomationDetailsPage(TbContext tbContext, String automationId, {super.key})
      : super(
          tbContext,
          entityId: automationId,
          defaultTitle: 'Automation',
          subTitle: 'Automation details',
        );

  @override
  Future<Automation?> fetchEntity(String id) async {
    AssetInfo? assetInfo = await tbClient.getAssetService().getAssetInfo(id);
    if (assetInfo == null) return null;
    Automation entity = Automation.fromAssetInfo(assetInfo);
    return entity;
  }

  @override
  Widget buildEntityDetails(BuildContext context, Automation entity) {
    print('buildEntityDetails: ${entity.toString()}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Ngữ cảnh thông minh'),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy bỏ'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildIfBlock(context, entity),
            const SizedBox(height: 16),
            _buildThenBlock(context, entity),
            const SizedBox(height: 16),
            _buildPreconditionDisplayArea(entity),
            const Spacer(),
            _buildSaveButton(context, entity),
          ],
        ),
      ),
    );
  }

  Widget _buildIfBlock(BuildContext context, Automation entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('If', 'Khi bất kỳ điều kiện nào được đáp ứng'),
          ...entity.smartScene.ifConditions.map((condition) {
            return ListTile(
              leading: const Icon(Icons.device_hub),
              title: Text(condition.entityId),
              subtitle: Text(condition.condition),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Optionally handle tap to edit/view condition
              },
            );
          }).toList(),
          _addButton(
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (context) => IfDevicesPage()),
                );
                if (result != null) {
                  DeviceInfo? device =
                      await DeviceManager.instance.getDevice(result['name']);
                  if (device != null) {
                    entity.smartScene.ifConditions.add(SceneCondition(
                      entityId: device.name,
                      condition: result['data'].toString(),
                    ));
                    buildEntityDetails(context, entity);
                  }
                }
              },
              tooltip: 'Thêm điều kiện'),
        ],
      ),
    );
  }

  Widget _buildThenBlock(BuildContext context, Automation entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Then',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const ListTile(
            title: Text('Thêm tác vụ', style: TextStyle(color: Colors.grey)),
          ),
          _addButton(
              onPressed: () async {
                final result = await Navigator.push<EntityData>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ThenDevicesListPage(tbContext),
                  ),
                );

                if (result != null) {
                  print(
                      '------------------- Selected Device: ${result.entityId}');
                  // setState(() {
                  //   selectedDevices.add(result);
                  // });
                }
              },
              tooltip: 'Thêm tác vụ'),
        ],
      ),
    );
  }

  Widget _buildPreconditionDisplayArea(Automation entity) {
    return Column(
      children: [
        ListTile(
          title: const Text('Precondition'),
          trailing: const Text('Cả ngày'),
          onTap: () {},
        ),
        ListTile(
          title: const Text('Display Area'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context, Automation entity) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          entity.update(
            name: 'Ngữ cảnh mới 2',
            active: true,
            ifConditions: [],
            thenActions: [],
            precondition: ScenePrecondition(from: '00:00', to: '23:59'),
            areaIds: ['areaId1'],
          );
          await tbClient.getAssetService().saveAsset(entity);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Lưu', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _addButton(
      {required VoidCallback onPressed, required String tooltip}) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: const Icon(Icons.add_circle, color: Colors.orange),
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
        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }
}
