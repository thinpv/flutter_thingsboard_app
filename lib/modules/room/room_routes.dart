import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';

import 'room_add_page.dart';
import 'room_details_page.dart';
import 'rooms_page.dart';

class RoomRoutes extends TbRoutes {
  late var roomsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return RoomsPage(tbContext, searchMode: searchMode);
    },
  );

  late var roomAddHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return RoomAddPage(tbContext);
    },
  );

  late var roomDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return RoomDetailsPage(tbContext, params['id'][0]);
    },
  );

  RoomRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/rooms', handler: roomsHandler);
    router.define('/room', handler: roomAddHandler);
    router.define('/room/:id', handler: roomDetailsHandler);
  }
}
