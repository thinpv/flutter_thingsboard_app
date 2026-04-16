import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/home/domain/entities/smarthome_device.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/device_state_provider.dart';
import 'package:thingsboard_app/modules/smarthome/home/providers/home_provider.dart';
import 'package:thingsboard_app/utils/services/smarthome/provisioning_service.dart';

/// Wizard to add a new IR or RF sub-device to a specific gateway.
///
/// Flow:
///   Step 1 — Choose gateway (required — IR/RF device must be tied to a GW)
///   Step 2 — Choose protocol (IR / RF) and device category
///   Step 3 — Choose template or "Custom (học lệnh)"
///   Step 4 — Enter device name → confirm
class AddIrRfDevicePage extends ConsumerStatefulWidget {
  const AddIrRfDevicePage({super.key});

  @override
  ConsumerState<AddIrRfDevicePage> createState() => _AddIrRfDevicePageState();
}

class _AddIrRfDevicePageState extends ConsumerState<AddIrRfDevicePage> {
  final _svc = ProvisioningService();
  final _pageCtrl = PageController();
  int _step = 0; // 0..3

  // ── Step 1 state ──
  List<SmarthomeDevice> _gateways = [];
  bool _loadingGateways = true;
  SmarthomeDevice? _selectedGw;

  // ── Step 2 state ──
  String _protocol = 'ir'; // 'ir' | 'rf'
  _DeviceCategory? _category;

  // ── Step 3 state ──
  _TemplateOption? _template; // null = custom

  // ── Step 4 state ──
  final _nameCtrl = TextEditingController();
  bool _adding = false;
  String? _addError;

  // ── Template catalogue (matches TB descriptor fixtures) ──
  static const _irCategories = <_DeviceCategory>[
    _DeviceCategory('tv',     'TV',          Icons.tv_outlined),
    _DeviceCategory('ac',     'Điều hòa',    Icons.ac_unit),
    _DeviceCategory('fan',    'Quạt IR',     Icons.air),
    _DeviceCategory('custom', 'Khác / Tự học', Icons.more_horiz),
  ];

  static const _rfCategories = <_DeviceCategory>[
    _DeviceCategory('fan',      'Quạt RF',    Icons.air),
    _DeviceCategory('socket',   'Ổ cắm RF',   Icons.electrical_services),
    _DeviceCategory('doorbell', 'Chuông RF',  Icons.notifications_outlined),
    _DeviceCategory('custom',   'Khác / Tự học', Icons.more_horiz),
  ];

  static const _templates = <String, List<_TemplateOption>>{
    'ir_tv': [
      _TemplateOption('ir.tv.lg_generic',      'LG (generic)',      'LG TV học mã NEC'),
      _TemplateOption('ir.tv.samsung_generic',  'Samsung (generic)', 'Samsung TV học mã'),
      _TemplateOption(null,                     'Tự học (custom)',   'Học toàn bộ lệnh từ remote thật'),
    ],
    'ir_ac': [
      _TemplateOption('ir.ac.lg_generic',      'LG AC',     'Điều hòa LG fixed code'),
      _TemplateOption('ir.ac.daikin_generic',   'Daikin AC', 'Điều hòa Daikin'),
      _TemplateOption(null,                     'Tự học (custom)', 'Học từng lệnh'),
    ],
    'ir_fan': [
      _TemplateOption('ir.fan.generic',         'Quạt (generic)', 'Quạt IR học mã NEC'),
      _TemplateOption(null,                     'Tự học (custom)', 'Học từng lệnh'),
    ],
    'ir_custom': [
      _TemplateOption(null, 'Tự học (custom)', 'Học toàn bộ lệnh từ remote thật'),
    ],
    'rf_fan': [
      _TemplateOption('rf.fan.ev1527_generic',  'EV1527 (generic)', 'Quạt RF 433MHz EV1527 học mã'),
      _TemplateOption(null,                     'Tự học (custom)',  'Học từng lệnh'),
    ],
    'rf_socket': [
      _TemplateOption('rf.socket.ev1527_generic', 'EV1527 socket', 'Ổ cắm RF EV1527'),
      _TemplateOption(null,                       'Tự học (custom)', 'Học từng lệnh'),
    ],
    'rf_doorbell': [
      _TemplateOption('rf.doorbell.ev1527_generic', 'EV1527 chuông', 'Chuông RF EV1527'),
      _TemplateOption(null,                         'Tự học (custom)', 'Học từng lệnh'),
    ],
    'rf_custom': [
      _TemplateOption(null, 'Tự học (custom)', 'Học toàn bộ lệnh từ remote thật'),
    ],
  };

  List<_DeviceCategory> get _categories =>
      _protocol == 'ir' ? _irCategories : _rfCategories;

  List<_TemplateOption> get _currentTemplates {
    if (_category == null) return [];
    final key = '${_protocol}_${_category!.id}';
    return _templates[key] ?? [
      const _TemplateOption(null, 'Tự học (custom)', 'Học từng lệnh'),
    ];
  }

  // ─── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
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
        // Auto-select if only 1 gateway
        if (gws.length == 1) {
          _selectedGw = gws.first;
        }
      });
    } catch (_) {
      setState(() => _loadingGateways = false);
    }
  }

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool get _canProceed => switch (_step) {
        0 => _selectedGw != null,
        1 => _category != null,
        2 => _template != null,
        3 => _nameCtrl.text.trim().isNotEmpty,
        _ => false,
      };

  // ─── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedGw == null || _category == null || _template == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _adding = true;
      _addError = null;
    });

    try {
      // 1. RPC tạo device trên GW (chờ GW tạo xong mới trả response)
      final subId = await _svc.addIrRfDevice(
        gatewayId: _selectedGw!.id,
        protocol: _protocol,
        deviceType: _category!.id,
        name: name,
        template: _template!.id,
      );

      // 2. Tìm TB entity ID bằng device name (= subId trên TB)
      //    và gán vào Home để hiển thị trong danh sách
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

  // ─── Build ──────────────────────────────────────────────────────────────────

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
          // Step indicator
          _StepIndicator(currentStep: _step, totalSteps: 4),

          // Pages
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
                _StepProtocol(
                  protocol: _protocol,
                  category: _category,
                  categories: _categories,
                  onProtocol: (p) => setState(() {
                    _protocol = p;
                    _category = null;
                    _template = null;
                  }),
                  onCategory: (c) => setState(() {
                    _category = c;
                    _template = null;
                  }),
                ),
                _StepTemplate(
                  templates: _currentTemplates,
                  selected: _template,
                  onSelect: (t) => setState(() => _template = t),
                ),
                _StepName(
                  controller: _nameCtrl,
                  protocol: _protocol,
                  category: _category,
                  template: _template,
                  adding: _adding,
                  error: _addError,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),

          // Bottom navigation
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _canProceed && !_adding ? _next : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _adding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_step == 3 ? 'Thêm thiết bị' : 'Tiếp tục'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step indicator ──────────────────────────────────────────────────────────

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

// ─── Step 1: Gateway selection ───────────────────────────────────────────────

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
          Text(
            'Chọn Gateway',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thiết bị IR/RF sẽ được quản lý bởi gateway này.\n'
            'Đảm bảo gateway đang kết nối và trong tầm phủ sóng.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
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
                      'Không tìm thấy gateway trong nhà.\n'
                      'Thêm gateway trước khi thêm thiết bị IR/RF.',
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
                subtitle: Text(gw.id, style: const TextStyle(fontSize: 11)),
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

// ─── Step 2: Protocol + Device category ─────────────────────────────────────

class _StepProtocol extends StatelessWidget {
  const _StepProtocol({
    required this.protocol,
    required this.category,
    required this.categories,
    required this.onProtocol,
    required this.onCategory,
  });
  final String protocol;
  final _DeviceCategory? category;
  final List<_DeviceCategory> categories;
  final ValueChanged<String> onProtocol;
  final ValueChanged<_DeviceCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Giao thức & Loại thiết bị',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Protocol toggle
          Row(
            children: [
              Expanded(
                child: _ProtoButton(
                  label: 'IR (hồng ngoại)',
                  icon: Icons.sensors,
                  selected: protocol == 'ir',
                  onTap: () => onProtocol('ir'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProtoButton(
                  label: 'RF (433 MHz)',
                  icon: Icons.wifi_tethering,
                  selected: protocol == 'rf',
                  onTap: () => onProtocol('rf'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'Loại thiết bị',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: categories.map((cat) {
              final selected = category?.id == cat.id;
              return InkWell(
                onTap: () => onCategory(cat),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: selected
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.3)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat.icon,
                        size: 20,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

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
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? color.withValues(alpha: 0.08)
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3: Template selection ───────────────────────────────────────────────

class _StepTemplate extends StatelessWidget {
  const _StepTemplate({
    required this.templates,
    required this.selected,
    required this.onSelect,
  });
  final List<_TemplateOption> templates;
  final _TemplateOption? selected;
  final ValueChanged<_TemplateOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Template predefined có sẵn lệnh — chỉ cần ghép và dùng.\n'
            'Tự học: remote giữ lại từng lệnh sau khi thêm.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),
          ...templates.map(
            (t) => RadioListTile<_TemplateOption>(
              value: t,
              groupValue: selected,
              title: Text(t.label),
              subtitle: Text(t.description,
                  style: const TextStyle(fontSize: 12)),
              secondary: Icon(
                t.id == null
                    ? Icons.school_outlined
                    : Icons.verified_outlined,
                color: t.id == null
                    ? Colors.orange
                    : Colors.green,
              ),
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

// ─── Step 4: Name entry + confirmation ───────────────────────────────────────

class _StepName extends StatelessWidget {
  const _StepName({
    required this.controller,
    required this.protocol,
    required this.category,
    required this.template,
    required this.adding,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String protocol;
  final _DeviceCategory? category;
  final _TemplateOption? template;
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
          Text(
            'Đặt tên thiết bị',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Summary card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  label: 'Giao thức',
                  value: protocol.toUpperCase(),
                ),
                if (category != null)
                  _SummaryRow(label: 'Loại', value: category!.label),
                if (template != null)
                  _SummaryRow(
                    label: 'Template',
                    value: template!.id ?? 'Tự học',
                  ),
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
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (template?.id == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chế độ tự học: sau khi thêm thiết bị, vào trang '
                      'điều khiển và nhấn nút học lệnh để dạy từng phím từ remote thật.',
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
    if (category == null) return 'VD: TV phòng khách';
    return switch (category!.id) {
      'tv'       => 'VD: TV phòng khách',
      'ac'       => 'VD: Điều hòa phòng ngủ',
      'fan'      => 'VD: Quạt phòng khách',
      'socket'   => 'VD: Ổ cắm đèn ngủ',
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
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _DeviceCategory {
  const _DeviceCategory(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _TemplateOption {
  const _TemplateOption(this.id, this.label, this.description);
  // id == null means "custom" (no predefined template)
  final String? id;
  final String label;
  final String description;
}
