import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/provider/scene_manager.dart';
import 'package:thingsboard_app/service/scene_service.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'scenes_list.dart';

class ScenesPage extends TbContextWidget {
  final bool searchMode;

  ScenesPage(
    TbContext tbContext, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _ScenesPageState();
}

class _ScenesPageState extends TbContextState<ScenesPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  Widget build(BuildContext context) {
    final scenesList = ScenesList(
      tbContext,
      _pageLinkController,
      searchMode: widget.searchMode,
    );
    PreferredSizeWidget appBar;
    if (widget.searchMode) {
      appBar = TbAppSearchBar(
        tbContext,
        onSearch: (searchText) => _pageLinkController.onSearchText(searchText),
      );
    } else {
      appBar = TbAppBar(
        tbContext,
        title: Text(scenesList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/scenes?search=true');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // navigateTo('/scene');
              final controller = TextEditingController();
              final sceneName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tạo kịch bản mới'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Tên kịch bản',
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
              if (sceneName != null) {
                final customerId =
                    widget.tbContext.tbClient.getAuthUser()?.customerId;
                if (customerId != null) {
                  Scene scene = Scene(name: sceneName);
                  scene.customerId = CustomerId(customerId);
                  scene = await SceneService.instance.saveScene(scene);
                  await SceneManager.instance.getScenesList(forceRefresh: true);
                  if (scene.id != null) {
                    navigateTo('/scene/${scene.id!.id}');
                  }
                }
              }
            },
          ),
        ],
      );
    }
    return Scaffold(appBar: appBar, body: scenesList);
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
