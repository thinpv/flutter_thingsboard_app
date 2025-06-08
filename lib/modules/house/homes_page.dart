import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';

import 'homes_list.dart';

class HomesPage extends TbContextWidget {
  final bool searchMode;

  HomesPage(
    TbContext tbContext, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _HomesPageState();
}

class _HomesPageState extends TbContextState<HomesPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  Widget build(BuildContext context) {
    final homesList = HomesList(
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
        title: Text(homesList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/homes?search=true');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              navigateTo('/home');
            },
          ),
        ],
      );
    }
    return Scaffold(appBar: appBar, body: homesList);
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
