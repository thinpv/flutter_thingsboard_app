import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/scenario_models.dart';
import 'package:thingsboard_app/provider/scenario_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

mixin ScenariosBase on EntitiesBase<Scenario, PageLink> {
  bool refresh = false;

  @override
  String get title => 'Scenarios';

  @override
  String get noItemsFoundText => 'No scenarios found';

  @override
  Future<PageData<Scenario>> fetchEntities(PageLink pageLink) async {
    var data = await ScenarioManager.instance
        .getScenariosPageData(pageLink: pageLink, forceRefresh: refresh);
    refresh = false;
    return data;
  }

  @override
  Future<void> onRefresh() {
    refresh = true;
    return Future.value();
  }

  @override
  void onEntityTap(Scenario scenario) {
    navigateTo('/scenario/${scenario.id!.id}');
  }

  @override
  Widget buildEntityListCard(BuildContext context, Scenario scenario) {
    return _buildCard(context, scenario);
  }

  @override
  Widget buildEntityListWidgetCard(BuildContext context, Scenario scenario) {
    return _buildListWidgetCard(context, scenario);
  }

  @override
  Widget buildEntityGridCard(BuildContext context, Scenario scenario) {
    return Text(scenario.getDisplayName());
  }

  Widget _buildCard(context, Scenario scenario) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(width: 16),
                Flexible(
                  fit: FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                scenario.getDisplayName(),
                                style: const TextStyle(
                                  color: Color(0xFF282828),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 20 / 14,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            entityDateFormat.format(
                              DateTime.fromMillisecondsSinceEpoch(
                                scenario.createdTime!,
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFFAFAFAF),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              height: 16 / 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scenario.type,
                        style: const TextStyle(
                          color: Color(0xFFAFAFAF),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.chevron_right, color: Color(0xFFACACAC)),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListWidgetCard(BuildContext context, Scenario scenario) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          scenario.getDisplayName(),
                          style: const TextStyle(
                            color: Color(0xFF282828),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.7,
                          ),
                        ),
                      ),
                      Text(
                        scenario.type,
                        style: const TextStyle(
                          color: Color(0xFFAFAFAF),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
