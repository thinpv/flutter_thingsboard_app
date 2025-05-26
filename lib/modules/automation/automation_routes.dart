import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/modules/automation/automations_page.dart';

import 'automation_details_page.dart';

class AutomationRoutes extends TbRoutes {
  late var automationsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return AutomationsPage(tbContext, searchMode: searchMode);
    },
  );

  late var automationDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return AutomationDetailsPage(tbContext, params['id'][0]);
    },
  );

  AutomationRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/automations', handler: automationsHandler);
    router.define('/automation/:id', handler: automationDetailsHandler);
  }
}
