import 'package:uuid/uuid.dart';

class SmarthomeScene {
  const SmarthomeScene({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.actions,
  });

  factory SmarthomeScene.fromJson(Map<String, dynamic> json) {
    final List<Map<String, dynamic>> actions;

    if (json.containsKey('actions')) {
      final raw = json['actions'] as List? ?? [];
      actions = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      // Backward compat: convert old {devices, notify} format to actions list.
      final devicesRaw = json['devices'] as Map<String, dynamic>? ?? {};
      actions = [
        for (final e in devicesRaw.entries)
          {
            'type': 'device',
            'deviceId': e.key,
            'data': Map<String, dynamic>.from(e.value as Map),
          },
      ];
      final notifyRaw = json['notify'] as Map<String, dynamic>?;
      if (notifyRaw != null) {
        actions.add({'type': 'notify', ...notifyRaw});
      }
    }

    return SmarthomeScene(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'auto_awesome',
      color: json['color'] as String? ?? '#2196F3',
      actions: actions,
    );
  }

  factory SmarthomeScene.empty() => SmarthomeScene(
        id: const Uuid().v4(),
        name: '',
        icon: 'auto_awesome',
        color: '#2196F3',
        actions: const [],
      );

  final String id;
  final String name;
  final String icon;
  final String color;

  /// Ordered list of actions executed when the scene is triggered.
  /// Uses the unified action format: {type, ...fields}.
  final List<Map<String, dynamic>> actions;

  SmarthomeScene copyWith({
    String? name,
    String? icon,
    String? color,
    List<Map<String, dynamic>>? actions,
  }) {
    return SmarthomeScene(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      actions: actions ?? this.actions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'actions': actions,
      };
}
