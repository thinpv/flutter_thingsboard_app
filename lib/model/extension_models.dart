import 'package:thingsboard_client/thingsboard_client.dart';

extension on EntityId {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType.toString().split('.').last,
    };
  }
}

extension on DeviceProfileInfo {
  Map<String, dynamic> toJson() {
    return {
      'id': id.toJson(),
      'name': name,
      'type': type.toShortString(),
      'transportType': transportType.toShortString(),
      'defaultDashboardId': defaultDashboardId?.toJson(),
      'image': image,
      'tenantId': tenantId.toJson(),
    };
  }
}

extension on TsValue {
  Map<String, dynamic> toJson() {
    return {
      'ts': ts,
      'value': value,
    };
  }
}

extension on ComparisonTsValue {
  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'previous': previous,
    };
  }
}

extension on EntityData {
  Map<String, dynamic> toJson() {
    return {
      'entityId': entityId.toJson(),
      'latest': latest.map((key, value) => MapEntry(
            key.toShortString(),
            value.map((k, v) => MapEntry(k, v)),
          )),
      'timeseries': timeseries.map(
          (key, value) => MapEntry(key, value.map((tsVal) => tsVal).toList())),
      'aggLatest':
          aggLatest.map((key, value) => MapEntry(key.toString(), value)),
    };
  }
}

extension on PageData<EntityData> {
  Map<String, dynamic> toJson() {
    return {
      'data': data.map((dynamic e) => e.toJson()).toList(),
      'totalPages': totalPages,
      'totalElements': totalElements,
      'hasNext': hasNext
    };
  }
}
