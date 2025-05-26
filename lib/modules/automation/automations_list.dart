import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'automations_base.dart';

class AutomationsList extends BaseEntitiesWidget<AssetInfo, PageLink>
    with AutomationsBase, EntitiesListStateBase {
  AutomationsList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);
}
