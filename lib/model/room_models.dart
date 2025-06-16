import 'package:thingsboard_client/thingsboard_client.dart';
import 'package:uuid/uuid.dart';

class Room extends Asset {
  late List<String> deviceIds;

  Room() : super(const Uuid().v4(), 'Room');

  Room.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    final info = json['additionalInfo'] as Map<String, dynamic>? ?? {};
    deviceIds = (info['deviceIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ?? [];
  }

  @override
  Map<String, dynamic> toJson() {
    additionalInfo ??= {};
    additionalInfo!['deviceIds'] = deviceIds;
      return super.toJson();
  }

  void addDevice(String deviceId) {
    if (!deviceIds.contains(deviceId)) {
      deviceIds.add(deviceId);
    }
  }

  void removeDevice(String deviceId) {
    deviceIds.remove(deviceId);
  }

  String getDisplayName() {
    if (label != null && label!.isNotEmpty) {
      return label!;
    } else {
      return name;
    }
  }
}

class RoomAdd extends Room {
  RoomAdd() : super();
}

class RoomInfo extends Room {
  String? customerTitle;
  bool? customerIsPublic;
  String roomProfileName = 'Room';

  RoomInfo.fromJson(Map<String, dynamic> json)
      : customerTitle = json['customerTitle'],
        customerIsPublic = json['customerIsPublic'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (customerTitle != null) json['customerTitle'] = customerTitle;
    if (customerIsPublic != null) json['customerIsPublic'] = customerIsPublic;
    json['assetProfileName'] = roomProfileName;
    return json;
  }

  @override
  String toString() {
    return 'RoomInfo{${assetString('roomProfileName: $roomProfileName, customerTitle: $customerTitle, customerIsPublic: $customerIsPublic')}}';
  }
}

class RoomSearchQuery extends EntitySearchQuery {
  List<String> roomTypes;

  RoomSearchQuery(
      {required RelationsSearchParameters parameters,
      required this.roomTypes,
      String? relationType})
      : super(parameters: parameters, relationType: relationType);

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['roomTypes'] = roomTypes;
    return json;
  }

  @override
  String toString() {
    return 'RoomSearchQuery{${entitySearchQueryString('roomTypes: $roomTypes')}}';
  }
}
