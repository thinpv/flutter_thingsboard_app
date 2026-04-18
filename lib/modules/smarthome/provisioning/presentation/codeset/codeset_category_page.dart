import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';

/// Bước 0+1: Chọn protocol (IR/RF) + category (TV, AC, Fan...).
///
/// Trả về [_CategorySelection] qua Navigator.pop().
class CodesetCategoryPage extends StatefulWidget {
  const CodesetCategoryPage({
    super.key,
    required this.catalogIndex,
  });

  final CatalogIndex catalogIndex;

  @override
  State<CodesetCategoryPage> createState() => _CodesetCategoryPageState();
}

class _CodesetCategoryPageState extends State<CodesetCategoryPage> {
  String _protocol = 'ir';
  String? _category;

  List<CatalogCategoryEntry> get _categories =>
      widget.catalogIndex.categoriesFor(_protocol);

  void _selectProtocol(String p) {
    setState(() {
      _protocol = p;
      _category = null;
    });
  }

  void _selectCategory(String cat) {
    setState(() => _category = cat);
    Navigator.pop(
      context,
      CodesetCategorySelection(protocol: _protocol, category: cat),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        title: const Text('Chọn loại thiết bị',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MpColors.text)),
        iconTheme: const IconThemeData(color: MpColors.text),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Giao thức',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: MpColors.text3, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ProtoButton(
                    label: kProtocolNames['ir']!['vi']!,
                    icon: Icons.sensors,
                    selected: _protocol == 'ir',
                    onTap: () => _selectProtocol('ir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProtoButton(
                    label: kProtocolNames['rf']!['vi']!,
                    icon: Icons.wifi_tethering,
                    selected: _protocol == 'rf',
                    onTap: () => _selectProtocol('rf'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Loại thiết bị',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: MpColors.text3, letterSpacing: 0.4)),
            const SizedBox(height: 8),

            if (_categories.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không có thiết bị ${_protocol.toUpperCase()} nào trong catalog.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MpColors.text3),
                  ),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: _categories.map((entry) {
                  return _CategoryCard(
                    category: entry.category,
                    name: entry.name,
                    selected: _category == entry.category,
                    onTap: () => _selectCategory(entry.category),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class CodesetCategorySelection {
  const CodesetCategorySelection({
    required this.protocol,
    required this.category,
  });
  final String protocol;
  final String category;
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ProtoButton extends StatelessWidget {
  const _ProtoButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? MpColors.text : MpColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? MpColors.text : MpColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? MpColors.bg : MpColors.text3, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? MpColors.bg : MpColors.text2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String category;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    const icons = <String, IconData>{
      'tv':        Icons.tv_outlined,
      'ac':        Icons.ac_unit,
      'fan':       Icons.air,
      'stb':       Icons.settings_input_hdmi_outlined,
      'projector': Icons.videocam_outlined,
      'switch':    Icons.toggle_on_outlined,
      'curtain':   Icons.blinds_outlined,
      'doorbell':  Icons.notifications_outlined,
      'gate':      Icons.garage_outlined,
      'socket':    Icons.electrical_services_outlined,
    };
    return icons[category] ?? Icons.devices_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? MpColors.text : MpColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? MpColors.text : MpColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 20, color: selected ? MpColors.bg : MpColors.text3),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? MpColors.bg : MpColors.text,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
