import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_list_widget.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/modules/rule/rules_base.dart';

class RulesListWidget extends EntitiesListPageLinkWidget<Rule>
    with RulesBase {
  RulesListWidget(
    TbContext tbContext, {
    super.key,
    EntitiesListWidgetController? controller,
  }) : super(tbContext, controller: controller);

  @override
  void onViewAll() {
    navigateTo('/rules');
  }
}
