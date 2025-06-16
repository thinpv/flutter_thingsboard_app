import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/home_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/service/home_service.dart';
import 'package:thingsboard_app/utils/utils.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class HomeAddPage extends StatefulWidget {
  final TbContext tbContext;

  const HomeAddPage(this.tbContext, {super.key});

  @override
  State<HomeAddPage> createState() => _HomeAddPageState();
}

class _HomeAddPageState extends State<HomeAddPage> {
  late Future<HomeAdd?> _homeAddFuture;
  late HomeAdd homeAdd;

  @override
  void initState() {
    super.initState();
    homeAdd = HomeAdd();
    _homeAddFuture = fetchEntity();
  }

  Future<HomeAdd?> fetchEntity() async {
    return Future.value(homeAdd);
  }

  void _refresh() {
    setState(() {
      _homeAddFuture = fetchEntity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeAdd?>(
      future: _homeAddFuture,
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

  Widget _buildEntityDetails(BuildContext context, HomeAdd entity) {
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
                newName != entity.name) {
              entity.name = newName.trim();
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
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 16),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
