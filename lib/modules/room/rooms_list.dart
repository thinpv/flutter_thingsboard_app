import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'rooms_base.dart';

class RoomsList extends BaseEntitiesWidget<Room, PageLink>
    with RoomsBase, EntitiesListStateBase {
  RoomsList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);
}
