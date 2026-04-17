import 'package:flutter/material.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';

/// Bước 2: Chọn brand/hãng từ catalog index (không cần fetch thêm).
class CodesetBrandPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final catName = catalogIndex.categoryName(protocol, category);
    final brands = catalogIndex.brandsFor(protocol, category);

    return Scaffold(
      appBar: AppBar(title: Text('Chọn hãng — $catName')),
      body: brands.isEmpty
          ? Center(
              child: Text(
                'Không có hãng nào trong danh mục $catName.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
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
    );
  }
}
