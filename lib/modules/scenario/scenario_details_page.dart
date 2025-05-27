import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entity_details_page.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'if/if_devices_page.dart';
import 'then/then_devices_page.dart';

class ScenarioDetailsPage extends EntityDetailsPage<Scenario> {
  ScenarioDetailsPage(TbContext tbContext, String scenarioId, {super.key})
      : super(
          tbContext,
          entityId: scenarioId,
          defaultTitle: 'Scenario',
          subTitle: 'Scenario details',
        );

  @override
  Future<Scenario?> fetchEntity(String id) async {
    AssetInfo? assetInfo = await tbClient.getAssetService().getAssetInfo(id);
    if (assetInfo == null) return null;
    Scenario entity = Scenario.fromAssetInfo(assetInfo);
    return entity;
  }

  @override
  Widget buildEntityDetails(BuildContext context, Scenario entity) {
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

  Widget _buildIfBlock(BuildContext context, Scenario entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('If', 'Khi bất kỳ điều kiện nào được đáp ứng'),
          ...entity.smartScene.ifConditions.map((condition) {
            return ListTile(
              leading: const Icon(Icons.device_hub),
              title: Text(condition.device.name),
              subtitle: Text(condition.condition),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Optionally handle tap to edit/view condition
              },
            );
          }).toList(),
          _addButton(
              onPressed: () async {
                final result = await Navigator.push<SceneCondition>(
                  context,
                  MaterialPageRoute(builder: (context) => IfDevicesPage()),
                );
                entity.smartScene.ifConditions.add(result!);
                entity.update(
                  ifConditions: entity.smartScene.ifConditions,
                );
                buildEntityDetails(context, entity);
              },
              tooltip: 'Thêm điều kiện'),
        ],
      ),
    );
  }

  Widget _buildThenBlock(BuildContext context, Scenario entity) {
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
                final result = await Navigator.push<SceneAction>(
                  context,
                  MaterialPageRoute(builder: (context) => ThenDevicesPage()),
                );
                print('Selected action: ${result?.toJson()}');
                entity.smartScene.thenActions.add(result!);
                buildEntityDetails(context, entity);
              },
              tooltip: 'Thêm tác vụ'),
        ],
      ),
    );
  }

  Widget _buildPreconditionDisplayArea(Scenario entity) {
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

  Widget _buildSaveButton(BuildContext context, Scenario entity) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          entity.update(
            name: 'Ngữ cảnh mới 2',
            active: true,
            ifConditions: [],
            thenActions: [],
            precondition: ScenePrecondition(
              DateTime.now().toString(),
              DateTime.now().add(const Duration(days: 1)).toString(),
            ),
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
