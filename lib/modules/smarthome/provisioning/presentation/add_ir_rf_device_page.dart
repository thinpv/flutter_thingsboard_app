import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_brand_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_category_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_model_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_test_page.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';

/// Wizard thêm thiết bị IR/RF mới.
///
/// Luồng:
///   Step 1 — Chọn Gateway
///   Step 2 — Browse catalog (protocol → category → brand → model → thử phím)
///            hoặc "Tự học" (custom binding)
///   Step 3 — Đặt tên thiết bị → xác nhận
class AddIrRfDevicePage extends ConsumerStatefulWidget {
  const AddIrRfDevicePage({
    this.initialGatewayId,
    this.initialProtocol,
    super.key,
  });

  /// Khi mở từ GatewayView, truyền ID gateway để bỏ qua bước chọn gateway.
  final String? initialGatewayId;

  /// 'ir' hoặc 'rf' — pre-select protocol khi mở từ nút cụ thể.
  final String? initialProtocol;

  @override
  ConsumerState<AddIrRfDevicePage> createState() => _AddIrRfDevicePageState();
}

class _AddIrRfDevicePageState extends ConsumerState<AddIrRfDevicePage> {
  final _svc = ProvisioningService();
  final _codesetSvc = CodesetService();
  final _pageCtrl = PageController();
  int _step = 0; // 0, 1, 2

  // ── Step 1 ──
  List<SmarthomeDevice> _gateways = [];
  bool _loadingGateways = true;
  SmarthomeDevice? _selectedGw;

  // ── Step 2 — Catalog state ──
  // null = chưa chọn, "custom" = tự học
  CodesetProfile? _selectedProfile;
  bool _isCustom = false;
  late String _selectedProtocol;
  String? _selectedCategory;
  CodesetCatalog? _catalog;
  bool _loadingCatalog = false;
  String? _catalogError;

  // ── Step 3 ──
  final _nameCtrl = TextEditingController();
  bool _adding = false;
  String? _addError;

  // ─── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedProtocol = widget.initialProtocol ?? 'ir';
    // Nếu đã có gateway (mở từ GatewayView), bắt đầu ở step 1
    if (widget.initialGatewayId != null) {
      _step = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageCtrl.jumpToPage(1);
      });
    }
    _loadGateways();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGateways() async {
    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) {
      setState(() => _loadingGateways = false);
      return;
    }
    try {
      final gws = await _svc.fetchGatewayDevices(home.id);
      setState(() {
        _gateways = gws;
        _loadingGateways = false;
        if (widget.initialGatewayId != null) {
          _selectedGw = gws.firstWhere(
            (g) => g.id == widget.initialGatewayId,
            orElse: () => gws.isNotEmpty ? gws.first : gws.first,
          );
        } else if (gws.length == 1) {
          _selectedGw = gws.first;
        }
      });
    } catch (_) {
      setState(() => _loadingGateways = false);
    }
  }

  Future<void> _loadCatalog(String protocol) async {
    if (_catalog != null && !_loadingCatalog) {
      // Đã có catalog, kiểm tra xem có protocol mới không
      final hasProtocol = _catalog!.profiles.any((p) => p.protocol == protocol);
      if (hasProtocol) return;
    }

    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });

    try {
      // Fetch cả 2 protocol cùng lúc để có full catalog
      final irCatalog = await _codesetSvc.fetchCatalog('ir');
      final rfCatalog = await _codesetSvc.fetchCatalog('rf');
      final allProfiles = [...irCatalog.profiles, ...rfCatalog.profiles];
      setState(() {
        _catalog = CodesetCatalog(profiles: allProfiles);
        _loadingCatalog = false;
      });
    } catch (e) {
      setState(() {
        _catalogError = e.toString();
        _loadingCatalog = false;
      });
    }
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _back() {
    final minStep = widget.initialGatewayId != null ? 1 : 0;
    if (_step > minStep) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  bool get _canProceed => switch (_step) {
        0 => _selectedGw != null,
        1 => _selectedProfile != null || _isCustom,
        2 => _nameCtrl.text.trim().isNotEmpty,
        _ => false,
      };

  // ─── Catalog browsing ────────────────────────────────────────────────────────

  Future<void> _browseCatalog() async {
    if (_catalog == null) {
      await _loadCatalog('ir');
    }
    if (_catalog == null || !mounted) return;

    // Bước 0+1: chọn protocol + category
    final catSel = await Navigator.push<CodesetCategorySelection>(
      context,
      MaterialPageRoute(
        builder: (_) => CodesetCategoryPage(catalog: _catalog!),
      ),
    );
    if (catSel == null || !mounted) return;

    setState(() {
      _selectedProtocol = catSel.protocol;
      _selectedCategory = catSel.category;
    });

    // Bước 2: chọn brand
    final brand = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CodesetBrandPage(
          catalog: _catalog!,
          protocol: catSel.protocol,
          category: catSel.category,
        ),
      ),
    );
    if (brand == null || !mounted) return;

    // Bước 3: chọn model
    final models =
        _catalog!.modelsFor(catSel.protocol, catSel.category, brand);
    final selectedModel = await Navigator.push<CodesetProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => CodesetModelPage(
          models: models,
          brand: brand,
          category: catSel.category,
        ),
      ),
    );
    if (selectedModel == null || !mounted) return;

    // Bước 4: thử phím (nếu profile có button_layout với proto)
    if (selectedModel.testButtons.isNotEmpty) {
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CodesetTestPage(
            profile: selectedModel,
            gatewayId: _selectedGw!.id,
          ),
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        // User không chọn → quay lại danh sách model
        return _browseCatalog();
      }
    }

    // User đã xác nhận → đặt profile đã chọn
    setState(() {
      _selectedProfile = selectedModel;
      _isCustom = false;
    });

    // Tự động suggest tên thiết bị
    if (_nameCtrl.text.isEmpty) {
      final defaultName = _buildDefaultName(selectedModel);
      _nameCtrl.text = defaultName;
    }

    // Tiến sang step đặt tên nếu đang ở step catalog
    if (_step == 1) _next();
  }

  String _buildDefaultName(CodesetProfile profile) {
    final cat = categoryDisplayName(profile.category);
    final brand = brandDisplayName(profile.brand);
    return '$brand $cat';
  }

  void _selectCustom() {
    setState(() {
      _isCustom = true;
      _selectedProfile = null;
    });
    if (_step == 1) _next();
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedGw == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _adding = true;
      _addError = null;
    });

    try {
      final template = _isCustom ? null : _selectedProfile?.profileName;
      final protocol = _isCustom ? _selectedProtocol : (_selectedProfile?.protocol ?? 'ir');
      final deviceType = _isCustom ? (_selectedCategory ?? 'custom') : (_selectedProfile?.category ?? 'custom');

      final subId = await _svc.addIrRfDevice(
        gatewayId: _selectedGw!.id,
        protocol: protocol,
        deviceType: deviceType,
        name: name,
        template: template,
      );

      final home = ref.read(selectedHomeProvider).valueOrNull;
      if (home != null && subId.isNotEmpty) {
        final tbEntityId = await _svc.findDeviceByName(subId);
        if (tbEntityId != null) {
          await _svc.assignToHome(tbEntityId, home.id);
        }
        ref.invalidate(devicesInHomeProvider(home.id));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm thiết bị "$name"'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _adding = false;
        _addError = e.toString();
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thiết bị IR / RF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _step, totalSteps: 3),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepGateway(
                  gateways: _gateways,
                  loading: _loadingGateways,
                  selected: _selectedGw,
                  onSelect: (gw) => setState(() => _selectedGw = gw),
                ),
                _StepCatalog(
                  selectedProfile: _selectedProfile,
                  isCustom: _isCustom,
                  isLoadingCatalog: _loadingCatalog,
                  catalogError: _catalogError,
                  onBrowse: _browseCatalog,
                  onCustom: _selectCustom,
                  onClear: () => setState(() {
                    _selectedProfile = null;
                    _isCustom = false;
                  }),
                ),
                _StepName(
                  controller: _nameCtrl,
                  selectedProfile: _selectedProfile,
                  isCustom: _isCustom,
                  protocol: _selectedProtocol,
                  category: _selectedCategory,
                  adding: _adding,
                  error: _addError,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _canProceed && !_adding ? _next : null,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: _adding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_step == 2 ? 'Thêm thiết bị' : 'Tiếp tục'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final active = i == currentStep;
          final done = i < currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: (active || done) ? color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1: Gateway ──────────────────────────────────────────────────────────

class _StepGateway extends StatelessWidget {
  const _StepGateway({
    required this.gateways,
    required this.loading,
    required this.selected,
    required this.onSelect,
  });
  final List<SmarthomeDevice> gateways;
  final bool loading;
  final SmarthomeDevice? selected;
  final ValueChanged<SmarthomeDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chọn Gateway',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Thiết bị IR/RF sẽ được quản lý bởi gateway này.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (gateways.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.router_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Không tìm thấy gateway trong nhà.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...gateways.map(
              (gw) => RadioListTile<SmarthomeDevice>(
                value: gw,
                groupValue: selected,
                title: Text(gw.displayName),
                subtitle:
                    Text(gw.id, style: const TextStyle(fontSize: 11)),
                secondary: const Icon(Icons.router_outlined),
                onChanged: (v) {
                  if (v != null) onSelect(v);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Step 2: Catalog browsing ─────────────────────────────────────────────────

class _StepCatalog extends StatelessWidget {
  const _StepCatalog({
    required this.selectedProfile,
    required this.isCustom,
    required this.isLoadingCatalog,
    required this.catalogError,
    required this.onBrowse,
    required this.onCustom,
    required this.onClear,
  });
  final CodesetProfile? selectedProfile;
  final bool isCustom;
  final bool isLoadingCatalog;
  final String? catalogError;
  final VoidCallback onBrowse;
  final VoidCallback onCustom;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chọn loại điều khiển',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Chọn từ catalog có sẵn hoặc tự học lệnh từ remote thật.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Đã chọn profile
          if (selectedProfile != null) ...[
            _SelectedProfileCard(
                profile: selectedProfile!, onClear: onClear),
            const SizedBox(height: 16),
          ],

          // Nút duyệt catalog
          if (selectedProfile == null && !isCustom) ...[
            // Error
            if (catalogError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Không tải được catalog: $catalogError\n'
                  'Vẫn có thể dùng chế độ tự học.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.orange.shade800),
                ),
              ),

            // Browse button
            OutlinedButton.icon(
              onPressed: isLoadingCatalog ? null : onBrowse,
              icon: isLoadingCatalog
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(isLoadingCatalog
                  ? 'Đang tải catalog...'
                  : 'Tìm remote từ catalog'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),

            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('hoặc', style: TextStyle(fontSize: 12)),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
          ],

          // Custom (tự học)
          if (!isCustom) ...[
            _CustomCard(
              selected: isCustom,
              onTap: onCustom,
            ),
          ] else ...[
            _CustomCard(selected: true, onTap: onClear),
          ],
        ],
      ),
    );
  }
}

class _SelectedProfileCard extends StatelessWidget {
  const _SelectedProfileCard(
      {required this.profile, required this.onClear});
  final CodesetProfile profile;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final brandName = brandDisplayName(profile.brand);
    final catName = categoryDisplayName(profile.category);
    final protoName =
        kProtocolNames[profile.protocol]?['vi'] ?? profile.protocol.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_remote_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName ?? '$brandName $catName',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$protoName · $brandName · ${profile.modelId}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (profile.buttonLayout.isNotEmpty)
                  Text(
                    '${profile.buttonLayout.length} nút đã có sẵn',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Chọn lại',
          ),
        ],
      ),
    );
  }
}

class _CustomCard extends StatelessWidget {
  const _CustomCard({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.school_outlined,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tự học (Custom)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const Text(
                    'Dạy từng phím từ remote thật sau khi thêm',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Name ─────────────────────────────────────────────────────────────

class _StepName extends StatelessWidget {
  const _StepName({
    required this.controller,
    required this.selectedProfile,
    required this.isCustom,
    required this.protocol,
    required this.category,
    required this.adding,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController controller;
  final CodesetProfile? selectedProfile;
  final bool isCustom;
  final String protocol;
  final String? category;
  final bool adding;
  final String? error;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đặt tên thiết bị',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  label: 'Giao thức',
                  value: (kProtocolNames[selectedProfile?.protocol ?? protocol]
                              ?['vi'] ??
                          protocol.toUpperCase()),
                ),
                if (selectedProfile != null) ...[
                  _SummaryRow(
                    label: 'Loại',
                    value: categoryDisplayName(selectedProfile!.category),
                  ),
                  _SummaryRow(
                    label: 'Remote',
                    value: selectedProfile!.displayName ??
                        '${brandDisplayName(selectedProfile!.brand)} (${selectedProfile!.modelId})',
                  ),
                ] else if (isCustom)
                  const _SummaryRow(
                      label: 'Chế độ', value: 'Tự học'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Tên thiết bị',
              hintText: _hint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.label_outline),
            ),
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.done,
          ),

          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isCustom) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chế độ tự học: sau khi thêm, vào trang điều khiển '
                      'và ấn nút học lệnh để dạy từng phím từ remote thật.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _hint {
    final cat = selectedProfile?.category ?? category;
    if (cat == null) return 'VD: Remote phòng khách';
    return switch (cat) {
      'tv'       => 'VD: TV phòng khách',
      'ac'       => 'VD: Điều hòa phòng ngủ',
      'fan'      => 'VD: Quạt phòng khách',
      'switch'   => 'VD: Công tắc đèn',
      'doorbell' => 'VD: Chuông cửa chính',
      _          => 'VD: Remote ${protocol.toUpperCase()}',
    };
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
