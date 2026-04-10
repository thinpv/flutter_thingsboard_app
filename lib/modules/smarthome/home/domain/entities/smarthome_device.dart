import 'package:thingsboard_app/thingsboard_client.dart';

/// Represents a sub-device belonging to a room.
/// Telemetry keys follow the unified short-key convention (onoff0, dim, temp…).
class SmarthomeDevice {
  const SmarthomeDevice({
    required this.id,
    required this.name,
    required this.type,
    this.label,
    this.deviceProfileId,
    this.uiType,
    this.profileImage,
    this.isOnline = false,
    this.telemetry = const {},
  });

  factory SmarthomeDevice.fromDevice(Device device) {
    return SmarthomeDevice(
      id: device.id!.id!,
      name: device.name,
      type: device.type,
      label: device.label,
      deviceProfileId: device.deviceProfileId?.id,
    );
  }

  final String id;
  final String name;
  final String type;
  final String? label;
  final String? deviceProfileId;

  /// UI type resolved from device server attribute (e.g. "switch", "light").
  final String? uiType;

  /// Device profile image URL from ThingsBoard (e.g. "tb-image;/api/images/...").
  final String? profileImage;
  final bool isOnline;

  /// Latest telemetry values keyed by short key (e.g. 'onoff0', 'dim', 'temp').
  final Map<String, dynamic> telemetry;

  /// Returns label if set, otherwise falls back to name.
  String get displayName =>
      (label != null && label!.isNotEmpty) ? label! : name;

  /// Effective UI type: resolved from server attr, else device type.
  String get effectiveUiType => uiType ?? type;

  SmarthomeDevice copyWith({
    bool? isOnline,
    String? label,
    String? uiType,
    String? profileImage,
    Map<String, dynamic>? telemetry,
  }) {
    return SmarthomeDevice(
      id: id,
      name: name,
      type: type,
      label: label ?? this.label,
      deviceProfileId: deviceProfileId,
      uiType: uiType ?? this.uiType,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
