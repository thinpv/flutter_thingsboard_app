import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/provider/scene_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

mixin ScenesBase on EntitiesBase<Scene, PageLink> {
  bool refresh = false;

  @override
  String get title => 'Scenes';

  @override
  String get noItemsFoundText => 'No scenes found';

  @override
  Future<PageData<Scene>> fetchEntities(PageLink pageLink) async {
    var data = await SceneManager.instance
        .getScenesPageData(pageLink: pageLink, forceRefresh: refresh);
    refresh = false;
    return data;
  }

  @override
  Future<void> onRefresh() {
    refresh = true;
    return Future.value();
  }

  @override
  void onEntityTap(Scene scene) {
    navigateTo('/scene/${scene.id!.id}');
  }

  @override
  Widget buildEntityListCard(BuildContext context, Scene scene) {
    return _buildCard(context, scene);
  }

  @override
  Widget buildEntityListWidgetCard(BuildContext context, Scene scene) {
    return _buildListWidgetCard(context, scene);
  }

  @override
  Widget buildEntityGridCard(BuildContext context, Scene scene) {
    return Text(scene.getDisplayName());
  }

  Widget _buildCard(context, Scene scene) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(width: 16),
                Flexible(
                  fit: FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                scene.getDisplayName(),
                                style: const TextStyle(
                                  color: Color(0xFF282828),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 20 / 14,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            entityDateFormat.format(
                              DateTime.fromMillisecondsSinceEpoch(
                                scene.createdTime!,
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFFAFAFAF),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              height: 16 / 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scene.type,
                        style: const TextStyle(
                          color: Color(0xFFAFAFAF),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.chevron_right, color: Color(0xFFACACAC)),
                // IconButton(
                //   icon: const Icon(Icons.delete),
                //   tooltip: 'Xóa',
                //   onPressed: () {
                //     SceneManager.instance.deleteScene(scene);
                //   },
                // ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListWidgetCard(BuildContext context, Scene scene) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          scene.getDisplayName(),
                          style: const TextStyle(
                            color: Color(0xFF282828),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.7,
                          ),
                        ),
                      ),
                      Text(
                        scene.type,
                        style: const TextStyle(
                          color: Color(0xFFAFAFAF),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
