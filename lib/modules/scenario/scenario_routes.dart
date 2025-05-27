import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/modules/scenario/scenarios_page.dart';

import 'scenario_details_page.dart';

class ScenarioRoutes extends TbRoutes {
  late var scenariosHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return ScenariosPage(tbContext, searchMode: searchMode);
    },
  );

  late var scenarioDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return ScenarioDetailsPage(tbContext, params['id'][0]);
    },
  );

  ScenarioRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/scenarios', handler: scenariosHandler);
    router.define('/scenario/:id', handler: scenarioDetailsHandler);
  }
}
