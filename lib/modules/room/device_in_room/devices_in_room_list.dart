import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/model/my_device_models.dart';
import 'package:thingsboard_app/modules/device/devices_base.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class DevicesInRoomList extends BaseEntitiesWidget<MyDeviceInfo, PageLink>
    with DevicesBase, EntitiesListStateBase {
  final bool displayDeviceImage;
  DevicesInRoomList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
    this.displayDeviceImage = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);

  @override
  bool displayCardImage(bool listWidgetCard) => displayDeviceImage;

  @override
  Future<PageData<MyDeviceInfo>> fetchEntities(PageLink pageLink) async {
    pageLink.textSearch = '2458';
    var data = await DeviceManager.instance
        .getMyDeviceInfosPageData(pageLink: pageLink, forceRefresh: refresh);
    refresh = false;
    return data;
  }
}
