import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_list_widget.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/modules/scenario/scenarios_base.dart';

class ScenariosListWidget extends EntitiesListPageLinkWidget<Scenario>
    with ScenariosBase {
  ScenariosListWidget(
    TbContext tbContext, {
    super.key,
    EntitiesListWidgetController? controller,
  }) : super(tbContext, controller: controller);

  @override
  void onViewAll() {
    navigateTo('/scenarios');
  }
}
