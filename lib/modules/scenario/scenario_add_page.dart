import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'if/if_devices_page.dart';
import 'then/then_devices_page.dart';

class ScenarioAddPage extends StatefulWidget {
  final TbContext tbContext;
  final ScenarioAdd scenarioAdd;

  ScenarioAddPage(this.tbContext, {super.key}) : scenarioAdd = ScenarioAdd();

  @override
  State<ScenarioAddPage> createState() => _ScenarioAddPageState();
}

class _ScenarioAddPageState extends State<ScenarioAddPage> {
  late Future<ScenarioAdd?> _scenarioAddFuture;

  @override
  void initState() {
    super.initState();
    _scenarioAddFuture = fetchEntity();
  }

  Future<ScenarioAdd?> fetchEntity() async {
    return Future.value(widget.scenarioAdd);
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
            final controller = TextEditingController(text: entity.name);
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
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            );
            if (newName != null &&
                newName.trim().isNotEmpty &&
                newName != entity.name) {
              entity.name = newName.trim();
              entity.update(name: entity.name);
              _refresh();
            }
          },
          child: Text(entity.name),
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
          _sectionTitle('If', 'Khi bất kỳ điều kiện nào được đáp ứng'),
          ...entity.smartScene.ifConditions.map((condition) {
            return ListTile(
              leading: const Icon(Icons.device_hub),
              title: Text(condition.device.name),
              subtitle: Text(condition.condition),
              trailing: const Icon(Icons.arrow_forward_ios),
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
                  entity.update(ifConditions: entity.smartScene.ifConditions);
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
          _sectionTitle('Then', 'Thêm tác vụ khi điều kiện đúng'),
          ...entity.smartScene.thenActions.map((action) {
            return ListTile(
              leading: const Icon(Icons.device_hub),
              title: Text(action.device.name),
              subtitle: Text(action.action),
              trailing: const Icon(Icons.arrow_forward_ios),
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
                  entity.update(thenActions: entity.smartScene.thenActions);
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
          Asset asset = Asset('name', 'Scenario');
          asset.additionalInfo = entity.additionalInfo;
          await widget.tbContext.tbClient.getAssetService().saveAsset(asset);
          _refresh();
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
        const BoxShadow(
            color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
  }
}
