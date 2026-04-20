import 'package:thingsboard_app/thingsboard_client.dart';

class SmarthomeHome {
  const SmarthomeHome({
    required this.id,
    required this.name,
    this.accentColor,
  });

  factory SmarthomeHome.fromAsset(Asset asset, {String? accentColor}) {
    return SmarthomeHome(
      id: asset.id!.id!,
      name: asset.name,
      accentColor: accentColor,
    );
  }

  final String id;
  final String name;

  /// Hex string, e.g. "#FF5722". null = dùng màu mặc định.
  final String? accentColor;

  SmarthomeHome copyWith({String? name, String? accentColor}) {
    return SmarthomeHome(
      id: id,
      name: name ?? this.name,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}
