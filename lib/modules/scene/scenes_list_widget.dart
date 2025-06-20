import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entities_list_widget.dart';
import 'package:thingsboard_app/model/scene_models.dart';

import 'scenes_base.dart';

class ScenesListWidget extends EntitiesListPageLinkWidget<Scene> with ScenesBase {
  ScenesListWidget(
    TbContext tbContext, {
    super.key,
    EntitiesListWidgetController? controller,
  }) : super(tbContext, controller: controller);

  @override
  void onViewAll() {
    navigateTo('/scenes');
  }
}
