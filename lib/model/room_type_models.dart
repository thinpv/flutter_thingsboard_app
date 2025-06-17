import 'dart:convert';

import 'package:thingsboard_app/thingsboard_client.dart';

class RoomType extends AssetProfile {
  RoomType.fromJson(Map<String, dynamic> json) : super.fromJson(json);
}

class RoomTypeInfo extends AssetProfileInfo {
  List<Map<String, dynamic>> conditions = [];
  List<Map<String, dynamic>> actions = [];
  List<Map<String, dynamic>> endpoints = [];
  Map<String, dynamic>? description;

  RoomTypeInfo.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
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
          endpoints =
              List<Map<String, dynamic>>.from(description?['endpoints'] ?? []);
        }
      }
    } catch (e) {
      print('RoomTypeInfo.fromJson: ${e}');
    }
  }

  Map<String, dynamic> toJson() {
    description ??= {};
    description!['conditions'] = conditions;
    description!['actions'] = actions;
    description!['endpoints'] = endpoints;
    Map<String, dynamic> json = {
      'id': id.toJson(),
      'name': name,
      'defaultDashboardId': defaultDashboardId?.toJson(),
      'image': image,
      'tenantId': tenantId?.toJson(),
      'description': description,
    };
    return json;
  }
}
