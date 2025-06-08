import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/service/room_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class RoomAddPage extends StatefulWidget {
  final TbContext tbContext;

  RoomAddPage(this.tbContext, {super.key});

  @override
  State<RoomAddPage> createState() => _RoomAddPageState();
}

class _RoomAddPageState extends State<RoomAddPage> {
  late Future<RoomAdd?> _roomAddFuture;
  late RoomAdd roomAdd;

  @override
  void initState() {
    super.initState();
    roomAdd = RoomAdd('Ten mac dinh');
    _roomAddFuture = fetchEntity();
  }

  Future<RoomAdd?> fetchEntity() async {
    return Future.value(roomAdd);
  }

  void _refresh() {
    setState(() {
      _roomAddFuture = fetchEntity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoomAdd?>(
      future: _roomAddFuture,
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

  Widget _buildEntityDetails(BuildContext context, RoomAdd entity) {
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

  Widget _buildIfBlock(BuildContext context, RoomAdd entity) {
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
              subtitle: Text(condition.name),
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
        ],
      ),
    );
  }

  Widget _buildThenBlock(BuildContext context, RoomAdd entity) {
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
              subtitle: Text(action.name),
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
        ],
      ),
    );
  }

  Widget _buildPreconditionDisplayArea(RoomAdd entity) {
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

  Widget _buildSaveButton(BuildContext context, RoomAdd entity) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final customerId =
              widget.tbContext.tbClient.getAuthUser()?.customerId;
          if (customerId != null) {
            entity.customerId = CustomerId(customerId);
            entity.smartScene.calculateDeviceSave();
            await RoomService.instance.saveRoom(entity);
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
