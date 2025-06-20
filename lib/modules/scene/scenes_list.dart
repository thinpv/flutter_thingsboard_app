import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/model/scene_models.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'scenes_base.dart';

class ScenesList extends BaseEntitiesWidget<Scene, PageLink>
    with ScenesBase, EntitiesListStateBase {
  ScenesList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);
}
