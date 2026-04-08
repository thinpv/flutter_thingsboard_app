import 'package:thingsboard_app/thingsboard_client.dart';

class SmarthomeRoom {
  const SmarthomeRoom({
    required this.id,
    required this.homeId,
    required this.name,
    this.icon,
    this.order = 0,
  });

  factory SmarthomeRoom.fromAsset(Asset asset, {required String homeId}) {
    return SmarthomeRoom(
      id: asset.id!.id!,
      homeId: homeId,
      name: asset.name,
    );
  }

  final String id;
  final String homeId;
  final String name;
  final String? icon;
  final int order;
}
