import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_brand_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_model_page.dart';
import 'package:thingsboard_app/modules/smarthome/provisioning/presentation/codeset/codeset_test_page.dart';
import 'package:thingsboard_app/utils/services/smarthome/codeset_service.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';

/// Wizard thêm thiết bị IR/RF mới.
///
/// Luồng:
///   Step 0 — Chọn Gateway (bỏ qua khi initialGatewayId != null)
///   Step 1 — Catalog inline: chọn category → brand → model → thử phím
///            hoặc "Tự học" (custom binding)
///   Step 2 — Đặt tên thiết bị → xác nhận
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
  int _step = 0;

  // ── Step 1: Gateway ──
  List<SmarthomeDevice> _gateways = [];
  bool _loadingGateways = true;
  SmarthomeDevice? _selectedGw;

  // ── Step 2: Catalog state ──
  CatalogIndex? _catalogIndex;
  bool _loadingCatalog = false;
  String? _catalogError;
  bool _loadingModels = false; // loading khi fetch models sau khi chọn brand

  CodesetProfile? _selectedProfile;
  bool _isCustom = false;
  late String _selectedProtocol;
  String? _selectedCategory;

  // ── Step 3 ──
  final _nameCtrl = TextEditingController();
  bool _adding = false;
  String? _addError;

  // ─── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedProtocol = widget.initialProtocol ?? 'ir';
    if (widget.initialGatewayId != null) {
      _step = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageCtrl.jumpToPage(1);
      });
    }
    _loadGateways();
    _loadCatalogIndex();
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

  Future<void> _loadCatalogIndex() async {
    if (_loadingCatalog) return;
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final index = await _codesetSvc.fetchCatalogIndex();
      setState(() {
        _catalogIndex = index;
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

  Future<void> _selectCategory(String protocol, String category) async {
    if (_catalogIndex == null || !mounted) return;

    setState(() {
      _selectedProtocol = protocol;
      _selectedCategory = category;
    });

    // Bước 1: chọn brand (từ catalog index — không cần fetch thêm)
    final brand = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CodesetBrandPage(
          catalogIndex: _catalogIndex!,
          protocol: protocol,
          category: category,
        ),
      ),
    );
    if (brand == null || !mounted) return;

    // Bước 2: fetch models cho brand đã chọn
    setState(() => _loadingModels = true);
    List<CodesetProfile> models;
    try {
      models = await _codesetSvc.fetchModels(protocol, category, brand);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingModels = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tải được danh sách remote: $e'),
            backgroundColor: MpColors.red,
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loadingModels = false);

    if (models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy remote nào cho hãng này')),
      );
      return;
    }

    // Bước 3: chọn model
    final brandName =
        _catalogIndex!.brandName(protocol, category, brand);
    final categoryName =
        _catalogIndex!.categoryName(protocol, category);

    final selectedModel = await Navigator.push<CodesetProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => CodesetModelPage(
          models: models,
          brandName: brandName,
          categoryName: categoryName,
        ),
      ),
    );
    if (selectedModel == null || !mounted) return;

    // Bước 4: thử phím (nếu có button layout)
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
      if (confirmed != true) return;
    }

    setState(() {
      _selectedProfile = selectedModel;
      _isCustom = false;
    });

    if (_nameCtrl.text.isEmpty) {
      _nameCtrl.text = _buildDefaultName(selectedModel);
    }

    if (_step == 1) _next();
  }

  String _buildDefaultName(CodesetProfile profile) {
    final catName = _catalogIndex?.categoryName(profile.protocol, profile.category)
        ?? profile.category;
    final brandName = _catalogIndex?.brandName(profile.protocol, profile.category, profile.brand)
        ?? profile.brand;
    return '$brandName $catName';
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

    final home = ref.read(selectedHomeProvider).valueOrNull;
    if (home == null) return;

    setState(() {
      _adding = true;
      _addError = null;
    });

    try {
      // Custom device: dùng "{protocol}.custom" để vẫn bị tính vào limit
      final deviceProfile = _isCustom
          ? '$_selectedProtocol.custom'
          : (_selectedProfile?.profileName ?? '$_selectedProtocol.custom');

      await _svc.addIrRfDevice(
        gatewayId:     _selectedGw!.id,
        homeId:        home.id,
        displayName:   name,
        deviceProfile: deviceProfile,
      );

      ref.invalidate(devicesInHomeProvider(home.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm thiết bị "$name"'),
            backgroundColor: MpColors.green,
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
      backgroundColor: MpColors.bg,
      appBar: AppBar(
        backgroundColor: MpColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MpColors.text),
        title: Text(
          'Thêm thiết bị ${kProtocolNames[_selectedProtocol]?['vi'] ?? _selectedProtocol.toUpperCase()}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: MpColors.text,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
      ),
      body: Stack(
        children: [
          Column(
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
                      catalogIndex: _catalogIndex,
                      isLoadingCatalog: _loadingCatalog,
                      catalogError: _catalogError,
                      protocol: _selectedProtocol,
                      onCategorySelect: _selectCategory,
                      onCustom: _selectCustom,
                      onRetry: _loadCatalogIndex,
                    ),
                    _StepName(
                      controller: _nameCtrl,
                      selectedProfile: _selectedProfile,
                      isCustom: _isCustom,
                      protocol: _selectedProtocol,
                      category: _selectedCategory,
                      catalogIndex: _catalogIndex,
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
                  child: GestureDetector(
                    onTap: (_canProceed && !_adding && !_loadingModels)
                        ? _next
                        : null,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: (_canProceed && !_adding && !_loadingModels)
                            ? MpColors.text
                            : MpColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _adding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: MpColors.bg))
                            : Text(
                                _step == 2 ? 'Thêm thiết bị' : 'Tiếp tục',
                                style: TextStyle(
                                  color: (_canProceed &&
                                          !_adding &&
                                          !_loadingModels)
                                      ? MpColors.bg
                                      : MpColors.text3,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay khi fetch models (giữa brand page và model page)
          if (_loadingModels)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MpColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: MpColors.text),
                      SizedBox(height: 12),
                      Text('Đang tải danh sách remote...',
                          style: TextStyle(
                              color: MpColors.text2, fontSize: 13)),
                    ],
                  ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final active = i == currentStep;
          final done = i < currentStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: (active || done) ? MpColors.text : MpColors.surfaceAlt,
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
          const Text('Chọn Gateway',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MpColors.text)),
          const SizedBox(height: 4),
          const Text(
            'Thiết bị IR/RF sẽ được quản lý bởi gateway này.',
            style: TextStyle(fontSize: 13, color: MpColors.text3),
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
                    const Icon(Icons.router_outlined,
                        size: 48, color: MpColors.text3),
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
              (gw) => InkWell(
                onTap: () => onSelect(gw),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected?.id == gw.id
                        ? MpColors.blueSoft
                        : MpColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected?.id == gw.id
                          ? MpColors.blue.withValues(alpha: 0.4)
                          : MpColors.border,
                      width: selected?.id == gw.id ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: MpColors.amberSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.router_outlined,
                            size: 18, color: MpColors.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(gw.displayName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: MpColors.text)),
                            Text(gw.id,
                                style: const TextStyle(
                                    fontSize: 11, color: MpColors.text3)),
                          ],
                        ),
                      ),
                      if (selected?.id == gw.id)
                        const Icon(Icons.check_circle,
                            size: 20, color: MpColors.blue),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Step 2: Catalog inline ───────────────────────────────────────────────────

class _StepCatalog extends StatelessWidget {
  const _StepCatalog({
    required this.catalogIndex,
    required this.isLoadingCatalog,
    required this.catalogError,
    required this.protocol,
    required this.onCategorySelect,
    required this.onCustom,
    required this.onRetry,
  });

  final CatalogIndex? catalogIndex;
  final bool isLoadingCatalog;
  final String? catalogError;
  final String protocol;
  final void Function(String protocol, String category) onCategorySelect;
  final VoidCallback onCustom;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final categories = catalogIndex?.categoriesFor(protocol) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildBody(context, categories)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('hoặc', style: TextStyle(fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: GestureDetector(
            onTap: onCustom,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: MpColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: MpColors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      color: MpColors.amber, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Tự học từ remote thật',
                    style: TextStyle(
                      color: MpColors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, List<CatalogCategoryEntry> categories) {
    if (isLoadingCatalog) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: MpColors.text),
          SizedBox(height: 12),
          Text('Đang tải catalog...',
              style: TextStyle(color: MpColors.text3)),
        ]),
      );
    }

    if (catalogError != null && catalogIndex == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                size: 48, color: MpColors.amber),
            const SizedBox(height: 12),
            const Text('Không tải được catalog',
                textAlign: TextAlign.center,
                style: TextStyle(color: MpColors.text)),
            const SizedBox(height: 4),
            Text(catalogError!,
                style: const TextStyle(fontSize: 12, color: MpColors.text3),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: MpColors.borderStrong),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Thử lại',
                    style: TextStyle(color: MpColors.text)),
              ),
            ),
          ]),
        ),
      );
    }

    if (categories.isEmpty) {
      return Center(
        child: Text(
          'Không có thiết bị ${protocol.toUpperCase()} nào trong catalog.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: MpColors.text3),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: categories
            .map((entry) => _CatCard(
                  entry: entry,
                  onTap: () => onCategorySelect(protocol, entry.category),
                ))
            .toList(),
      ),
    );
  }
}

class _CatCard extends StatelessWidget {
  const _CatCard({required this.entry, required this.onTap});
  final CatalogCategoryEntry entry;
  final VoidCallback onTap;

  IconData get _icon => const <String, IconData>{
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
      }[entry.category] ??
      Icons.devices_outlined;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: MpColors.surface,
          border: Border.all(color: MpColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 20, color: MpColors.text2),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                entry.name,
                style: const TextStyle(
                    fontSize: 13, color: MpColors.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
    required this.catalogIndex,
    required this.adding,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController controller;
  final CodesetProfile? selectedProfile;
  final bool isCustom;
  final String protocol;
  final String? category;
  final CatalogIndex? catalogIndex;
  final bool adding;
  final String? error;
  final VoidCallback onChanged;

  String _catName(String? cat) {
    if (cat == null) return '';
    final proto = selectedProfile?.protocol ?? protocol;
    return catalogIndex?.categoryName(proto, cat) ?? cat;
  }

  String _brandName(CodesetProfile p) =>
      catalogIndex?.brandName(p.protocol, p.category, p.brand) ?? p.brand;

  String _protocolName(String proto) =>
      kProtocolNames[proto]?['vi'] ?? proto.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final proto = selectedProfile?.protocol ?? protocol;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đặt tên thiết bị',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MpColors.text)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MpColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  label: 'Giao thức',
                  value: _protocolName(proto),
                ),
                if (selectedProfile != null) ...[
                  _SummaryRow(
                    label: 'Loại',
                    value: _catName(selectedProfile!.category),
                  ),
                  _SummaryRow(
                    label: 'Remote',
                    value: selectedProfile!.displayName ??
                        '${_brandName(selectedProfile!)} (${selectedProfile!.modelId})',
                  ),
                ] else if (isCustom)
                  const _SummaryRow(label: 'Chế độ', value: 'Tự học'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: MpColors.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: _hint,
              hintStyle: const TextStyle(color: MpColors.text3),
              labelText: 'Tên thiết bị',
              labelStyle: const TextStyle(color: MpColors.text2),
              prefixIcon: const Icon(Icons.label_outline,
                  size: 18, color: MpColors.text2),
              filled: true,
              fillColor: MpColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: MpColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: MpColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: MpColors.blue, width: 1.5),
              ),
            ),
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.done,
          ),

          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MpColors.redSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: MpColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: MpColors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                          color: MpColors.red, fontSize: 13),
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
                color: MpColors.amberSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: MpColors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: MpColors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chế độ tự học: sau khi thêm, vào trang điều khiển '
                      'và ấn nút học lệnh để dạy từng phím từ remote thật.',
                      style: TextStyle(fontSize: 13, color: MpColors.text2),
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
                style: const TextStyle(
                    fontSize: 12, color: MpColors.text3)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MpColors.text)),
          ),
        ],
      ),
    );
  }
}
