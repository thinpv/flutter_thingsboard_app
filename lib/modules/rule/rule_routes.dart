import 'package:fluro/fluro.dart';
import 'package:flutter/widgets.dart';
import 'package:thingsboard_app/config/routes/router.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/modules/rule/rules_page.dart';

import 'rule_add_page.dart';
import 'rule_details_page.dart';

class RuleRoutes extends TbRoutes {
  late var rulesHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      var searchMode = params['search']?.first == 'true';
      return RulesPage(tbContext, searchMode: searchMode);
    },
  );

  late var ruleAddHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return RuleAddPage(tbContext);
    },
  );

  late var ruleDetailsHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, dynamic> params) {
      return RuleDetailsPage(tbContext, params['id'][0]);
    },
  );

  RuleRoutes(TbContext tbContext) : super(tbContext);

  @override
  void doRegisterRoutes(router) {
    router.define('/rules', handler: rulesHandler);
    router.define('/rule', handler: ruleAddHandler);
    router.define('/rule/:id', handler: ruleDetailsHandler);
  }
}
