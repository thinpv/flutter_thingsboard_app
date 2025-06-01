import 'dart:convert';

import 'package:thingsboard_app/thingsboard_client.dart';

class DeviceType extends DeviceProfile {
  DeviceType.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}

class DeviceTypeInfo extends DeviceProfileInfo {
  List<Map<String, dynamic>> conditions = [];
  List<Map<String, dynamic>> actions = [];

  DeviceTypeInfo.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    try {
      Map<String, dynamic>? description;
      if (json['description'] is String) {
        var decoded = jsonDecode(json['description']);
        if (decoded is Map<String, dynamic>) {
          description = decoded;
        }
      } else if (json['description'] is Map<String, dynamic>) {
        description = json['description'];
      }
      if (description != null) {
        conditions =
            List<Map<String, dynamic>>.from(description['conditions'] ?? []);
        actions = List<Map<String, dynamic>>.from(description['actions'] ?? []);
      }
    } catch (e) {
      print('DeviceTypeInfo.fromJson: ${e}');
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
    json['description'] = {
      'conditions': conditions,
      'actions': actions,
    };
    return json;
  }
}
