import 'package:thingsboard_app/thingsboard_client.dart';

/// Represents a sub-device belonging to a room.
/// Telemetry keys follow the unified short-key convention (onoff0, dim, temp…).
class SmarthomeDevice {
  const SmarthomeDevice({
    required this.id,
    required this.name,
    required this.type,
    this.label,
    this.gatewayName,
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

  /// TB device label — set by admin in TB UI or via server attr `defaultLabel`.
  /// Always human-readable. Takes highest priority in displayName.
  final String? label;

  /// Friendly name published by the gateway via client attribute `name`.
  /// Kept separate from [label] because gateway may publish a raw MAC/UUID
  /// before a human-readable name is provisioned. Used as final fallback
  /// after [profileName] so it never causes a UUID flash.
  final String? gatewayName;

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

  /// 4-level display name priority:
  ///   1. `label`       — TB device label (admin-set, always human-readable)
  ///   2. `profileName` — device type name from profile description (always human-readable)
  ///   3. `gatewayName` — gateway-published client attr `name` (may be MAC/UUID on old firmware)
  ///   4. `name`        — raw TB device name (may be UUID-like)
  ///
  /// [gatewayName] intentionally ranks below [profileName] so that a UUID-like
  /// gateway name never displaces the human-readable profile type name.
  String get displayName {
    if (label != null && label!.isNotEmpty) return label!;
    if (profileName != null && profileName!.isNotEmpty) return profileName!;
    if (gatewayName != null && gatewayName!.isNotEmpty) return gatewayName!;
    return name;
  }

  /// True once we have at least one human-readable name source (label or
  /// profileName). gatewayName is intentionally excluded: the gateway may
  /// publish a raw MAC/UUID as clientAttr `name` before the device is fully
  /// provisioned, and using it here would bypass the skeleton guard.
  bool get isNameResolved =>
      (label?.isNotEmpty ?? false) ||
      (profileName?.isNotEmpty ?? false) ||
      (gatewayName?.isNotEmpty ?? false);

  /// Effective UI type: resolved from server attr, else device type.
  String get effectiveUiType => uiType ?? type;

  SmarthomeDevice copyWith({
    bool? isOnline,
    String? label,
    String? gatewayName,
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
      gatewayName: gatewayName ?? this.gatewayName,
      profileName: profileName ?? this.profileName,
      deviceProfileId: deviceProfileId,
      uiType: uiType ?? this.uiType,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
