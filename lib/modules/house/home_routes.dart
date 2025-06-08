import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';

import 'home_add_page.dart';
import 'home_details_page.dart';
import 'homes_page.dart';

class HomeRoutes extends TbRoutes {
  late var homesHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return HomesPage(tbContext, searchMode: searchMode);
    },
  );

  late var homeAddHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return HomeAddPage(tbContext);
    },
  );

  late var homeDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return HomeDetailsPage(tbContext, params['id'][0]);
    },
  );

  HomeRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/homes', handler: homesHandler);
    router.define('/home', handler: homeAddHandler);
    router.define('/home/:id', handler: homeDetailsHandler);
  }
}
