import 'package:uuid/uuid.dart';

class SmarthomeScene {
  const SmarthomeScene({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.devices,
  });

  factory SmarthomeScene.fromJson(Map<String, dynamic> json) {
    final devicesRaw = json['devices'] as Map<String, dynamic>? ?? {};
    return SmarthomeScene(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'auto_awesome',
      color: json['color'] as String? ?? '#2196F3',
      devices: devicesRaw.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      ),
    );
  }

  factory SmarthomeScene.empty() => SmarthomeScene(
        id: const Uuid().v4(),
        name: '',
        icon: 'auto_awesome',
        color: '#2196F3',
        devices: {},
      );

  final String id;
  final String name;
  final String icon;
  final String color;

  /// deviceId → {key: value} target state (uses unified short keys)
  final Map<String, Map<String, dynamic>> devices;

  SmarthomeScene copyWith({
    String? name,
    String? icon,
    String? color,
    Map<String, Map<String, dynamic>>? devices,
  }) {
    return SmarthomeScene(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      devices: devices ?? this.devices,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'devices': devices,
      };
}
