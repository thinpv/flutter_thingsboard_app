import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'scenarios_base.dart';

class ScenariosList extends BaseEntitiesWidget<AssetInfo, PageLink>
    with ScenariosBase, EntitiesListStateBase {
  ScenariosList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);
}
