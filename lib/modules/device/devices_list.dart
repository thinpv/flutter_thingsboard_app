import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'devices_base.dart';

class DevicesList extends BaseEntitiesWidget<MyDeviceInfo, PageLink>
    with DevicesBase, EntitiesListStateBase {
  final bool displayDeviceImage;
  DevicesList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    this.displayDeviceImage = false,
  }) : super(tbContext, pageKeyController);

  @override
  bool displayCardImage(bool listWidgetCard) => displayDeviceImage;
}
