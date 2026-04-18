import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';

/// Bước 3: Danh sách model remotes — user chọn remote giống với remote thật.
class CodesetModelPage extends StatefulWidget {
  const CodesetModelPage({
    super.key,
    required this.models,
    required this.brandName,
    required this.categoryName,
  });

  final List<CodesetProfile> models;

  /// Tên hiển thị của brand, vd: "Samsung"
  final String brandName;

  /// Tên hiển thị của category, vd: "Tivi"
  final String categoryName;

  @override
  State<CodesetModelPage> createState() => _CodesetModelPageState();
}

class _CodesetModelPageState extends State<CodesetModelPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CodesetProfile> get _filtered {
    if (_query.isEmpty) return widget.models;
    final q = _query.toLowerCase();
    return widget.models.where((m) {
      final name = (m.displayName ?? '').toLowerCase();
      final modelId = m.modelId.toLowerCase();
      final meta = m.codesetMeta;
      final hint = (meta?['modelsHint'] as String? ?? '').toLowerCase();
      return name.contains(q) || modelId.contains(q) || hint.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.brandName} ${widget.categoryName}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm model, tên remote...',
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

          // Hướng dẫn
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MpColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: MpColors.text2),
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
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Không có remote nào.'
                          : 'Không tìm thấy remote "$_query".',
                      style: const TextStyle(color: MpColors.text3),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final model = filtered[i];
                      return _ModelTile(
                        model: model,
                        brandName: widget.brandName,
                        query: _query,
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
  const _ModelTile({
    required this.model,
    required this.brandName,
    required this.query,
    required this.onTap,
  });
  final CodesetProfile model;
  final String brandName;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName =
        model.displayName ?? '$brandName (${model.modelId})';
    final subtitle = _buildSubtitle();

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _ModelImage(image: model.image, modelId: model.modelId),
      title: _highlight(displayName, query, context),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${model.buttonLayout.length} nút',
            style: const TextStyle(fontSize: 11, color: MpColors.text3),
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
    if (meta['yearRange'] != null) parts.add(meta['yearRange'] as String);
    if (meta['modelsHint'] != null) parts.add(meta['modelsHint'] as String);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _highlight(String text, String query, BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: const TextStyle(fontWeight: FontWeight.w500));
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(text,
          style: const TextStyle(fontWeight: FontWeight.w500));
    }
    return Text.rich(TextSpan(
      style: const TextStyle(fontWeight: FontWeight.w500),
      children: [
        if (idx > 0) TextSpan(text: text.substring(0, idx)),
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: const TextStyle(
            backgroundColor: MpColors.surfaceAlt,
            color: MpColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (idx + query.length < text.length)
          TextSpan(text: text.substring(idx + query.length)),
      ],
    ));
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
        try {
          final bytes = Uri.parse(image!).data?.contentAsBytes();
          if (bytes != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(bytes,
                  width: 56, height: 56, fit: BoxFit.contain),
            );
          }
        } catch (_) {}
      }
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: MpColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MpColors.border, width: 0.5),
      ),
      child: const Icon(Icons.settings_remote_outlined, color: MpColors.text3),
    );
  }
}
