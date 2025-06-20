import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';

import 'device_in_scene/scene_details_page.dart';
import 'scenes_page.dart';

class SceneRoutes extends TbRoutes {
  late var scenesHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return ScenesPage(tbContext, searchMode: searchMode);
    },
  );

  // late var sceneAddHandler = Handler(
  //   handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
  //     return SceneAddPage(tbContext);
  //   },
  // );

  late var sceneDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return SceneDetailsPage(tbContext, params['id'][0],
          searchMode: searchMode);
    },
  );

  SceneRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/scenes', handler: scenesHandler);
    // router.define('/scene', handler: sceneAddHandler);
    router.define('/scene/:id', handler: sceneDetailsHandler);
  }
}
