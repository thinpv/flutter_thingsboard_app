import 'package:flutter/material.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/model/rule_models.dart';
import 'package:thingsboard_app/provider/room_manager.dart';

import 'component/then_room_actions_page.dart';

class ThenRoomsPage extends StatelessWidget {
  const ThenRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<RoomInfo> rooms = RoomManager.instance.roomsList;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn phòng')),
      body: ListView.builder(
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return ListTile(
            title: Text(room.getDisplayName()),
            onTap: () async {
              final result = await Navigator.push<RuleActionRoom>(
                context,
                MaterialPageRoute(
                  builder: (context) => ThenRoomActionsPage(room.id!.id!),
                ),
              );
              Navigator.pop(context, result);
            },
          );
        },
      ),
    );
  }
}
