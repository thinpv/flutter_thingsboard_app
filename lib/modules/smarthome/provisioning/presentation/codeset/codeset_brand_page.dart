import 'package:flutter/material.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';

/// Bước 2: Chọn brand/hãng từ danh sách brands có sẵn trong catalog.
class CodesetBrandPage extends StatelessWidget {
  const CodesetBrandPage({
    super.key,
    required this.catalog,
    required this.protocol,
    required this.category,
  });

  final CodesetCatalog catalog;
  final String protocol;
  final String category;

  @override
  Widget build(BuildContext context) {
    final brands = catalog.brandsFor(protocol, category);
    final catName = categoryDisplayName(category);

    return Scaffold(
      appBar: AppBar(title: Text('Chọn hãng — $catName')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: brands.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, i) {
          final brand = brands[i];
          final displayName = brandDisplayName(brand);
          final modelCount = catalog
              .modelsFor(protocol, category, brand)
              .length;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(displayName),
            subtitle: Text(
              '$modelCount remote',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, brand),
          );
        },
      ),
    );
  }
}
