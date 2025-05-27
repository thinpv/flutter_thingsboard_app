import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/modules/scenario/then_devices_base.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class ThenDevicesList extends BaseEntitiesWidget<EntityData, EntityDataQuery>
    with ThenDevicesBase, EntitiesListStateBase {
  final bool displayDeviceImage;

  ThenDevicesList(
    TbContext tbContext,
    PageKeyController<EntityDataQuery> pageKeyController, {
    super.key,
    searchMode = false,
    this.displayDeviceImage = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);

  @override
  bool displayCardImage(bool listWidgetCard) => displayDeviceImage;
}
