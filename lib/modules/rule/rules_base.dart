import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/rule_manager.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

mixin RulesBase on EntitiesBase<Rule, PageLink> {
  bool refresh = false;

  @override
  String get title => 'Rules';

  @override
  String get noItemsFoundText => 'No rules found';

  @override
  Future<PageData<Rule>> fetchEntities(PageLink pageLink) async {
    var data = await RuleManager.instance
        .getRulesPageData(pageLink: pageLink, forceRefresh: refresh);
    refresh = false;
    return data;
  }

  @override
  Future<void> onRefresh() {
    refresh = true;
    return Future.value();
  }

  @override
  void onEntityTap(Rule rule) {
    navigateTo('/rule/${rule.id!.id}');
  }

  @override
  Widget buildEntityListCard(BuildContext context, Rule rule) {
    return _buildCard(context, rule);
  }

  @override
  Widget buildEntityListWidgetCard(BuildContext context, Rule rule) {
    return _buildListWidgetCard(context, rule);
  }

  @override
  Widget buildEntityGridCard(BuildContext context, Rule rule) {
    return Text(rule.getDisplayName());
  }

  Widget _buildCard(context, Rule rule) {
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
                                rule.getDisplayName(),
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
                                rule.createdTime!,
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
                        rule.type,
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
                IconButton(
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Color(0xFFACACAC),
                  ),
                  onPressed: () async {
                    final rpcBody = {
                      'method': 'control_rule',
                      'params': {
                        'id': rule.id!.id,
                      },
                    };
                    RequestConfig requestConfig = RequestConfig(
                      ignoreLoading: true,
                      ignoreErrors: true,
                    );
                    await tbContext.tbClient
                        .getDeviceService()
                        .handleOneWayDeviceRPCRequest(
                          rule.calculateDeviceSave()!,
                          rpcBody,
                          requestConfig: requestConfig,
                        );
                  },
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListWidgetCard(BuildContext context, Rule rule) {
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
                          rule.getDisplayName(),
                          style: const TextStyle(
                            color: Color(0xFF282828),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.7,
                          ),
                        ),
                      ),
                      Text(
                        rule.type,
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
