import 'package:flutter/material.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';

/// Bước 3: Danh sách model remotes — user chọn remote giống với remote thật.
class CodesetModelPage extends StatelessWidget {
  const CodesetModelPage({
    super.key,
    required this.models,
    required this.brand,
    required this.category,
  });

  final List<CodesetProfile> models;
  final String brand;
  final String category;

  @override
  Widget build(BuildContext context) {
    final brandName = brandDisplayName(brand);
    final catName = categoryDisplayName(category);

    return Scaffold(
      appBar: AppBar(title: Text('$brandName $catName')),
      body: Column(
        children: [
          // Hướng dẫn
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tìm remote giống với remote bạn đang cầm. '
                    'Bạn có thể thử phím ở bước tiếp theo.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: models.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final model = models[i];
                return _ModelTile(
                  model: model,
                  onTap: () => Navigator.pop(context, model),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.onTap});
  final CodesetProfile model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = model.displayName ??
        '${brandDisplayName(model.brand)} (${model.modelId})';
    final subtitle = _buildSubtitle();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _ModelImage(image: model.image, modelId: model.modelId),
      title: Text(displayName,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${model.buttonLayout.length} nút',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  String? _buildSubtitle() {
    final meta = model.codesetMeta;
    if (meta == null) return null;
    final parts = <String>[];
    if (meta['year_range'] != null) parts.add(meta['year_range'] as String);
    if (meta['models_hint'] != null) parts.add(meta['models_hint'] as String);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _ModelImage extends StatelessWidget {
  const _ModelImage({this.image, required this.modelId});
  final String? image;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    if (image != null && image!.isNotEmpty) {
      if (image!.startsWith('data:') || image!.length > 200) {
        // Base64 image
        try {
          final bytes = Uri.parse(image!).data?.contentAsBytes();
          if (bytes != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(bytes, width: 56, height: 56,
                  fit: BoxFit.contain),
            );
          }
        } catch (_) {}
      }
    }

    // Fallback icon
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.settings_remote_outlined,
        color: Colors.grey.shade400,
      ),
    );
  }
}
