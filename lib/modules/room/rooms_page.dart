import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';

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
            onPressed: () {
              navigateTo('/room');
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
