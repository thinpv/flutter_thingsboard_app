import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/entity/entity_details_page.dart';
import 'package:thingsboard_app/model/automation_models.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

class AutomationDetailsPage extends EntityDetailsPage<AssetInfo> {
  AutomationDetailsPage(TbContext tbContext, String automationId, {super.key})
      : super(
          tbContext,
          entityId: automationId,
          defaultTitle: 'Automation',
          subTitle: 'Automation details',
        );

  @override
  Future<AssetInfo?> fetchEntity(String id) {
    return tbClient.getAssetService().getAssetInfo(id);
  }

  @override
  Widget buildEntityDetails(BuildContext context, AssetInfo assetInfo) {
    Automation entity = Automation.fromAssetInfo(assetInfo);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(S.of(context).automationName, style: labelTextStyle),
          Text(entity.name, style: valueTextStyle),
          const SizedBox(height: 16),
          Text(S.of(context).type, style: labelTextStyle),
          Text(entity.type, style: valueTextStyle),
          const SizedBox(height: 16),
          Text(S.of(context).label, style: labelTextStyle),
          Text(entity.label ?? '', style: valueTextStyle),
          const SizedBox(height: 16),
          Text(
            S.of(context).assignedToCustomer,
            style: labelTextStyle,
          ),
          Text(entity.customerTitle ?? '', style: valueTextStyle),
          Text('rule value: ${entity.rule ?? ''}', style: valueTextStyle),
        ],
      ),
    );
  }
}
