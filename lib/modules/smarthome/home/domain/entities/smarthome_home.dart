import 'package:thingsboard_app/thingsboard_client.dart';

class SmarthomeHome {
  const SmarthomeHome({required this.id, required this.name});

  factory SmarthomeHome.fromAsset(Asset asset) {
    return SmarthomeHome(
      id: asset.id!.id!,
      name: asset.name,
    );
  }

  final String id;
  final String name;
}
