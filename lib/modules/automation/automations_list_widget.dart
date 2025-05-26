import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_list_widget.dart';
import 'package:thingsboard_app/modules/automation/automations_base.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

class AutomationsListWidget extends EntitiesListPageLinkWidget<AssetInfo>
    with AutomationsBase {
  AutomationsListWidget(
    TbContext tbContext, {
    super.key,
    EntitiesListWidgetController? controller,
  }) : super(tbContext, controller: controller);

  @override
  void onViewAll() {
    navigateTo('/automations');
  }
}
