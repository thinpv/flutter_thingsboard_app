import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_grid.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'devices_base.dart';

class DevicesGrid extends BaseEntitiesWidget<DeviceInfo, PageLink>
    with DevicesBase, EntitiesGridStateBase {
  DevicesGrid(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
  }) : super(tbContext, pageKeyController);
}
