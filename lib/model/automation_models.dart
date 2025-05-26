import 'package:thingsboard_client/thingsboard_client.dart';

class Automation extends AssetInfo {
  String? rule;

  Automation.fromJson(super.json) : super.fromJson() {
    rule = additionalInfo?['rule'] as String?;
  }

  Automation.fromAssetInfo(AssetInfo info) : super.fromJson(info.toJson()) {
    rule = additionalInfo?['rule'] as String?;
  }

  // Automation.fromAssetInfo(AssetInfo assetInfo) {
  //   // rule = assetInfo.additionalInfo?['rule'] as String?;
  // }

  void setRule(String? rule) {
    this.rule = rule;
    additionalInfo ??= {};
    additionalInfo!['rule'] = rule;
    // tbClient.getAssetService().saveAsset(this);
  }

  @override
  String toString() {
    return 'Automation{${assetString('assetProfileName: $assetProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}
