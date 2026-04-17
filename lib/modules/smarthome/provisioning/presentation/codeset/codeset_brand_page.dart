import 'package:flutter/material.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';

/// Bước 2: Chọn brand/hãng từ catalog index (không cần fetch thêm).
class CodesetBrandPage extends StatefulWidget {
  const CodesetBrandPage({
    super.key,
    required this.catalogIndex,
    required this.protocol,
    required this.category,
  });

  final CatalogIndex catalogIndex;
  final String protocol;
  final String category;

  @override
  State<CodesetBrandPage> createState() => _CodesetBrandPageState();
}

class _CodesetBrandPageState extends State<CodesetBrandPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.catalogIndex.categoryName(widget.protocol, widget.category);
    final allBrands = widget.catalogIndex.brandsFor(widget.protocol, widget.category);
    final brands = _query.isEmpty
        ? allBrands
        : allBrands
            .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Chọn hãng — $catName')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Tìm hãng...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: brands.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Không có hãng nào trong danh mục $catName.'
                          : 'Không tìm thấy hãng "$_query".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: brands.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final entry = brands[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            entry.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.count} remote',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, entry.brand),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
