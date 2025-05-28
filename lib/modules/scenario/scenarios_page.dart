import 'package:flutter/material.dart';
import 'package:thingsboard_app/core/context/tb_context.dart';
import 'package:thingsboard_app/core/context/tb_context_widget.dart';
import 'package:thingsboard_app/core/entity/entities_base.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';

import 'scenarios_list.dart';

class ScenariosPage extends TbContextWidget {
  final bool searchMode;

  ScenariosPage(
    TbContext tbContext, {
    this.searchMode = false,
    super.key,
  }) : super(tbContext);

  @override
  State<StatefulWidget> createState() => _ScenariosPageState();
}

class _ScenariosPageState extends TbContextState<ScenariosPage> {
  final PageLinkController _pageLinkController = PageLinkController();

  @override
  Widget build(BuildContext context) {
    final scenariosList = ScenariosList(
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
        title: Text(scenariosList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              navigateTo('/scenarios?search=true');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              navigateTo('/scenario');
            },
          ),
        ],
      );
    }
    return Scaffold(appBar: appBar, body: scenariosList);
  }

  @override
  void dispose() {
    _pageLinkController.dispose();
    super.dispose();
  }
}
