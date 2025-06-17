import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/core/entity/entities_list.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

import 'rules_base.dart';

class RulesList extends BaseEntitiesWidget<Rule, PageLink>
    with RulesBase, EntitiesListStateBase {
  RulesList(
    TbContext tbContext,
    PageKeyController<PageLink> pageKeyController, {
    super.key,
    searchMode = false,
  }) : super(tbContext, pageKeyController, searchMode: searchMode);
}
