import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
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
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        title: Text('Chọn hãng — $catName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MpColors.text)),
        iconTheme: const IconThemeData(color: MpColors.text),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: MpColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MpColors.border, width: 0.5),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                style: const TextStyle(fontSize: 14, color: MpColors.text),
                decoration: InputDecoration(
                  hintText: 'Tìm hãng...',
                  hintStyle: const TextStyle(color: MpColors.text3, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 18, color: MpColors.text3),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(Icons.clear, size: 16, color: MpColors.text3),
                        )
                      : null,
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
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
                      style: const TextStyle(color: MpColors.text3),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: brands.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, color: MpColors.border),
                    itemBuilder: (context, i) {
                      final entry = brands[i];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, entry.brand),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: MpColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: MpColors.border, width: 0.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  entry.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: MpColors.text2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.name,
                                        style: const TextStyle(fontSize: 14, color: MpColors.text)),
                                    Text('${entry.count} remote',
                                        style: const TextStyle(fontSize: 12, color: MpColors.text3)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: MpColors.text3),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
