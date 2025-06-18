import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_list_widget.dart';
import 'package:thingsboard_app/model/home_models.dart';

import 'homes_base.dart';

class HomesListWidget extends EntitiesListPageLinkWidget<HomeInfo> with HomesBase {
  HomesListWidget(
    TbContext tbContext, {
    super.key,
    EntitiesListWidgetController? controller,
  }) : super(tbContext, controller: controller);

  @override
  void onViewAll() {
    navigateTo('/homes');
  }
}
