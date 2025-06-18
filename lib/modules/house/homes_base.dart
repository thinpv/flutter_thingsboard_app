import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/home_models.dart';
import 'package:thingsboard_app/provider/home_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

mixin HomesBase on EntitiesBase<HomeInfo, PageLink> {
  bool refresh = false;

  @override
  String get title => 'Homes';

  @override
  String get noItemsFoundText => 'No homes found';

  @override
  Future<PageData<HomeInfo>> fetchEntities(PageLink pageLink) async {
    var data = await HomeManager.instance
        .getHomesPageData(pageLink: pageLink, forceRefresh: refresh);
    refresh = false;
    return data;
  }

  @override
  Future<void> onRefresh() {
    refresh = true;
    return Future.value();
  }

  @override
  void onEntityTap(HomeInfo homeInfo) {
    navigateTo('/home/${homeInfo.id!.id}');
  }

  @override
  Widget buildEntityListCard(BuildContext context, HomeInfo homeInfo) {
    return _buildCard(context, homeInfo);
  }

  @override
  Widget buildEntityListWidgetCard(BuildContext context, HomeInfo homeInfo) {
    return _buildListWidgetCard(context, homeInfo);
  }

  @override
  Widget buildEntityGridCard(BuildContext context, HomeInfo homeInfo) {
    return Text(homeInfo.getDisplayName());
  }

  Widget _buildCard(context, HomeInfo homeInfo) {
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
                                homeInfo.getDisplayName(),
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
                                homeInfo.createdTime!,
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
                        homeInfo.type,
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

  Widget _buildListWidgetCard(BuildContext context, HomeInfo homeInfo) {
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
                          homeInfo.getDisplayName(),
                          style: const TextStyle(
                            color: Color(0xFF282828),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.7,
                          ),
                        ),
                      ),
                      Text(
                        homeInfo.type,
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
