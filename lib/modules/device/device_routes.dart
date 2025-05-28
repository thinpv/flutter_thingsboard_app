import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';

import 'device_details_page.dart';
import 'devices_grid.dart';
import 'devices_list_page.dart';
import 'devices_main_page.dart';

class DeviceRoutes extends TbRoutes {
  late var devicesGridHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      final PageLinkController _pageLinkController = PageLinkController();
      return DevicesGrid(tbContext, _pageLinkController);
    },
  );

  late var devicesHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      // var searchMode = params['search']?.first == 'true';
      return DevicesMainPage(tbContext);
    },
  );

  late final deviceListHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      var deviceType = params['deviceType']?.first;
      String? activeStr = params['active']?.first;
      bool? active = activeStr != null ? activeStr == 'true' : null;
      return DevicesListPage(
        tbContext,
        searchMode: searchMode,
        deviceType: deviceType,
        active: active,
      );
    },
  );

  late var deviceDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return DeviceDetailsPage(tbContext, params['id'][0]);
    },
  );

  DeviceRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/devicesGrid', handler: devicesGridHandler);
    router.define('/devices', handler: devicesHandler);
    router.define('/deviceList', handler: deviceListHandler);
    router.define('/device/:id', handler: deviceDetailsHandler);
  }
}
