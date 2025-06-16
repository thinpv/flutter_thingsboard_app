import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/model/home_models.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/provider/device_type_manager.dart';
import 'package:thingsboard_app/provider/home_manager.dart';
import 'package:thingsboard_app/service/home_service.dart';
import 'package:thingsboard_app/utils/utils.dart';

class HomeDetailsPage extends StatefulWidget {
  final TbContext tbContext;
  final String homeId;

  const HomeDetailsPage(this.tbContext, this.homeId, {super.key});

  @override
  State<HomeDetailsPage> createState() => _HomeDetailsPageState();
}

class _HomeDetailsPageState extends State<HomeDetailsPage> {
  late Future<Home?> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = fetchEntity(widget.homeId);
  }

  Future<Home?> fetchEntity(String id) async {
    return HomeManager.instance.getHomeById(id);
  }

  void _refresh() {
    setState(() {
      _homeFuture = fetchEntity(widget.homeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Home?>(
      future: _homeFuture,
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

  Widget _buildEntityDetails(BuildContext context, Home entity) {
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
