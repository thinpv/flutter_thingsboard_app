import 'package:thingsboard_client/thingsboard_client.dart';

extension DeviceInfoExtension on DeviceInfo {
  String getGatewayId() {
    if (additionalInfo != null &&
        additionalInfo!['lastConnectedGateway'] != null) {
      return additionalInfo!['lastConnectedGateway'];
    }
    return '';
  }

  String getDisplayName() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    } else {
      return name;
    }
  }
}
