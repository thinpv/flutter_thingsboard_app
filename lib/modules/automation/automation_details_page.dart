import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entity_details_page.dart';
import 'package:thingsboard_app/model/automation_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class AutomationDetailsPage extends EntityDetailsPage<AssetInfo> {
  AutomationDetailsPage(TbContext tbContext, String automationId, {super.key})
      : super(
          tbContext,
          entityId: automationId,
          defaultTitle: 'Automation',
          subTitle: 'Automation details',
        );

  @override
  Future<AssetInfo?> fetchEntity(String id) {
    return tbClient.getAssetService().getAssetInfo(id);
  }

  @override
  Widget buildEntityDetails(BuildContext context, AssetInfo assetInfo) {
    Automation entity = Automation.fromAssetInfo(assetInfo);
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
            _buildIfBlock(entity),
            const SizedBox(height: 16),
            _buildThenBlock(entity),
            const SizedBox(height: 16),
            _buildPreconditionDisplayArea(entity),
            const Spacer(),
            _buildSaveButton(entity, context),
          ],
        ),
      ),
    );
  }

  Widget _buildIfBlock(Automation entity) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('If', 'Khi bất kỳ điều kiện nào được đáp ứng'),
          ListTile(
            leading: const Icon(Icons.garage),
            title: const Text('cửa cuốn 3'),
            subtitle: const Text('Door : closed'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {}, // navigate to condition detail
          ),
          _addButton(onPressed: () {}, tooltip: 'Thêm điều kiện'),
        ],
      ),
    );
  }

  Widget _buildThenBlock(Automation entity) {
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
          _addButton(onPressed: () {}, tooltip: 'Thêm tác vụ'),
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

  Widget _buildSaveButton(Automation entity, BuildContext context) {
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
