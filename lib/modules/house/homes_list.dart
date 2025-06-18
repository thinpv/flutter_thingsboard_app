import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/model/home_models.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'homes_base.dart';

class HomesList extends BaseEntitiesWidget<HomeInfo, PageLink>
    with HomesBase, EntitiesListStateBase {
  HomesList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);
}
