import 'dart:convert';

import 'package:thingsboard_app/thingsboard_client.dart';

class DeviceType extends DeviceProfile {
  DeviceType.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}

class DeviceTypeInfo extends DeviceProfileInfo {
  List<Map<String, dynamic>> conditions = [];
  List<Map<String, dynamic>> actions = [];
  Map<String, dynamic>? description;

  DeviceTypeInfo.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    try {
      if (json['description'] != null) {
        if (json['description'] is String) {
          description = jsonDecode(json['description']);
        } else if (json['description'] is Map<String, dynamic>) {
          description = json['description'];
        }
        if (description != null) {
          conditions =
              List<Map<String, dynamic>>.from(description?['conditions'] ?? []);
          actions =
              List<Map<String, dynamic>>.from(description?['actions'] ?? []);
        }
      }
    } catch (e) {
      print('DeviceTypeInfo.fromJson: ${e}');
    }
  }

  Map<String, dynamic> toJson() {
    description ??= {};
    description!['conditions'] = conditions;
    description!['actions'] = actions;
    Map<String, dynamic> json = {
      'id': id.toJson(),
      'name': name,
      'type': type.toShortString(),
      'transportType': transportType.toShortString(),
      'defaultDashboardId': defaultDashboardId?.toJson(),
      'image': image,
      'tenantId': tenantId.toJson(),
      'description': description,
    };
    return json;
  }
}
