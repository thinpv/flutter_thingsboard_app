import 'package:thingsboard_app/thingsboard_client.dart';

class DeviceType extends DeviceProfile {
  DeviceType.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}

class DeviceTypeInfo extends DeviceProfileInfo {
  Map<String, dynamic> conditions = {};
  Map<String, dynamic> actions = {};

  DeviceTypeInfo.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    try {
      final info = json['description'] as Map<String, dynamic>? ?? {};
      conditions = info['conditions'] != null
          ? Map<String, dynamic>.from(info['conditions'])
          : {};
      actions = info['actions'] != null
          ? Map<String, dynamic>.from(info['actions'])
          : {};
    } catch (e) {
      print('e: ${e}');
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'id': id.toJson(),
      'name': name,
      'type': type.toShortString(),
      'transportType': transportType.toShortString(),
      'defaultDashboardId': defaultDashboardId?.toJson(),
      'image': image,
      'tenantId': tenantId.toJson(),
    };

    if (conditions.isNotEmpty) {
      json['description']['conditions'] = conditions;
    }
    if (actions.isNotEmpty) json['description']['actions'] = actions;
    return json;
  }
}
