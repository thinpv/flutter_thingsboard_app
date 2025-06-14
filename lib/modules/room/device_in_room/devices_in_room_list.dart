import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/modules/device/devices_base.dart';
import 'package:thingsboard_app/provider/device_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class DevicesInRoomList extends BaseEntitiesWidget<DeviceInfo, PageLink>
    with DevicesBase, EntitiesListStateBase {
  final String roomId;
  final bool displayDeviceImage;

  DevicesInRoomList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController,
    this.roomId, {
    super.key,
    searchMode = false,
    this.displayDeviceImage = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);

  @override
  bool displayCardImage(bool listWidgetCard) => displayDeviceImage;

  @override
  Future<PageData<DeviceInfo>> fetchEntities(PageLink pageLink) async {
    refresh = false;
    AssetId assetId = AssetId(roomId);
    final listRelation =
        await tbClient.getEntityRelationService().findInfoByFrom(assetId);
    List<DeviceInfo> list = [];
    for (final relation in listRelation) {
      final device =
          DeviceManager.instance.getDeviceInfoByName(relation.toName);
      if (device != null) {
        list.add(device);
      }
    }
    return PageData<DeviceInfo>(list, 1, list.length, false);
  }
}
