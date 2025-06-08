import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';

import 'devices_in_room_list.dart';

class RoomDetailsPage extends TbContextWidget {
  final bool searchMode;
  final String roomId;

  RoomDetailsPage(
    TbContext tbContext,
    this.roomId, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends TbContextState<RoomDetailsPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  Widget build(BuildContext context) {
    final roomDetailsList = DevicesInRoomList(
      tbContext,
      _pageLinkController,
      searchMode: widget.searchMode,
      displayDeviceImage: true,
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
        title: Text(roomDetailsList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/room/?id=${widget.roomId}&search=true');
            },
          ),
        ],
      );
    }
    return Scaffold(appBar: appBar, body: roomDetailsList);
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
