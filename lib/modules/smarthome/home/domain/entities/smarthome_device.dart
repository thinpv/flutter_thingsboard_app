import 'package:thingsboard_app/thingsboard_client.dart';

/// Represents a sub-device belonging to a room.
/// Telemetry keys follow the unified short-key convention (onoff0, dim, temp…).
class SmarthomeDevice {
  const SmarthomeDevice({
    required this.id,
    required this.name,
    required this.type,
    this.label,
    this.isOnline = false,
    this.telemetry = const {},
  });

  factory SmarthomeDevice.fromDevice(Device device) {
    return SmarthomeDevice(
      id: device.id!.id!,
      name: device.name,
      type: device.type,
      label: device.label,
    );
  }

  final String id;
  final String name;
  final String type;
  final String? label;
  final bool isOnline;

  /// Latest telemetry values keyed by short key (e.g. 'onoff0', 'dim', 'temp').
  final Map<String, dynamic> telemetry;

  SmarthomeDevice copyWith({
    bool? isOnline,
    Map<String, dynamic>? telemetry,
  }) {
    return SmarthomeDevice(
      id: id,
      name: name,
      type: type,
      label: label,
      isOnline: isOnline ?? this.isOnline,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}
