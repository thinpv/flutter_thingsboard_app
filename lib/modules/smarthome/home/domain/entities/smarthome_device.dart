import 'package:thingsboard_app/thingsboard_client.dart';

/// Represents a sub-device belonging to a room.
/// Telemetry keys follow the unified short-key convention (onoff0, dim, temp…).
class SmarthomeDevice {
  const SmarthomeDevice({
    required this.id,
    required this.name,
    required this.type,
    this.label,
    this.profileName,
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

  /// Localized device type name from profile `description.i18n.vi.name`
  /// (e.g. "Ổ cắm thông minh"). Populated asynchronously from the profile
  /// metadata cache — may be null until resolution completes.
  final String? profileName;
  final String? deviceProfileId;

  /// UI type resolved from device server attribute (e.g. "switch", "light").
  final String? uiType;

  /// Device profile image URL from ThingsBoard (e.g. "tb-image;/api/images/...").
  final String? profileImage;
  final bool isOnline;

  /// Latest telemetry values keyed by short key (e.g. 'onoff0', 'dim', 'temp').
  final Map<String, dynamic> telemetry;

  /// 3-level display name priority:
  ///   1. `label`        — TB device label (user-set)
  ///   2. `profileName`  — from `description.i18n.vi.name` of device profile
  ///   3. `name`         — TB device name (raw identifier)
  String get displayName {
    if (label != null && label!.isNotEmpty) return label!;
    if (profileName != null && profileName!.isNotEmpty) return profileName!;
    return name;
  }

  /// Effective UI type: resolved from server attr, else device type.
  String get effectiveUiType => uiType ?? type;

  SmarthomeDevice copyWith({
    bool? isOnline,
    String? label,
    String? profileName,
    String? uiType,
    String? profileImage,
    Map<String, dynamic>? telemetry,
  }) {
    return SmarthomeDevice(
      id: id,
      name: name,
      type: type,
      label: label ?? this.label,
      profileName: profileName ?? this.profileName,
      deviceProfileId: deviceProfileId,
      uiType: uiType ?? this.uiType,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
