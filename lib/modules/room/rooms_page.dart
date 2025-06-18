import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/messages.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/model/room_models.dart';
import 'package:thingsboard_app/provider/room_manager.dart';
import 'package:thingsboard_app/service/room_service.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';
import 'package:thingsboard_client/thingsboard_client.dart';

import 'rooms_list.dart';

class RoomsPage extends TbContextWidget {
  final bool searchMode;

  RoomsPage(
    TbContext tbContext, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _RoomsPageState();
}

class _RoomsPageState extends TbContextState<RoomsPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  Widget build(BuildContext context) {
    final roomsList = RoomsList(
      tbContext,
      _pageLinkController,
      searchMode: widget.searchMode,
    );
    PreferredSizeWidget appBar;
    if (widget.searchMode) {
      appBar = TbAppSearchBar(
        tbContext,
        onSearch: (searchText) => _pageLinkController.onSearchText(searchText),
      );
    } else {
      appBar = TbAppBar(
        tbContext,
        title: Text(roomsList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/rooms?search=true');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // navigateTo('/room');
              final controller = TextEditingController();
              final roomName = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tạo phòng mới'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Tên phòng',
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: Text(S.of(context).save),
                    ),
                  ],
                ),
              );
              final customerId =
                  widget.tbContext.tbClient.getAuthUser()?.customerId;
              if (customerId != null) {
                Room room = Room(name: roomName);
                room.customerId = CustomerId(customerId);
                room = await RoomService.instance.saveRoom(room);
                await RoomManager.instance.getRoomsList(forceRefresh: true);
                if (room.id != null) {
                  navigateTo('/room/${room.id!.id}');
                }
              }
            },
          ),
        ],
      );
    }
    return Scaffold(appBar: appBar, body: roomsList);
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
