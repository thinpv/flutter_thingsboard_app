import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_list_widget.dart';
import 'package:thingsboard_app/model/room_models.dart';

import 'rooms_base.dart';

class RoomsListWidget extends EntitiesListPageLinkWidget<Room> with RoomsBase {
  RoomsListWidget(
    TbContext tbContext, {
    super.key,
    EntitiesListWidgetController? controller,
  }) : super(tbContext, controller: controller);

  @override
  void onViewAll() {
    navigateTo('/rooms');
  }
}
