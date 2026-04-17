import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

// ── Catalog Index models ─────────────────────────────────────────────────────

/// Một brand entry trong catalog index.
class CatalogBrandEntry {
  const CatalogBrandEntry({
    required this.brand,
    required this.name,
    required this.count,
  });

  factory CatalogBrandEntry._fromJson(Map<String, dynamic> j) =>
      CatalogBrandEntry(
        brand: j['brand'] as String,
        name: j['name'] as String? ?? (j['brand'] as String),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );

  /// Key ngắn, vd: "samsung"
  final String brand;

  /// Tên hiển thị, vd: "Samsung"
  final String name;

  /// Số models có sẵn
  final int count;
}

/// Một category entry trong catalog index.
class CatalogCategoryEntry {
  const CatalogCategoryEntry({
    required this.category,
    required this.name,
    required this.brands,
  });

  factory CatalogCategoryEntry._fromJson(Map<String, dynamic> j) =>
      CatalogCategoryEntry(
        category: j['category'] as String,
        name: j['name'] as String? ?? (j['category'] as String),
        brands: (j['brands'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogBrandEntry._fromJson)
            .toList(),
      );

  /// Key ngắn, vd: "tv"
  final String category;

  /// Tên hiển thị, vd: "Tivi"
  final String name;

  final List<CatalogBrandEntry> brands;
}

/// Catalog index đọc từ Device Profile "catalog" trên TB.
///
/// Schema:
/// ```json
/// { "v": 1, "type": "catalog",
///   "protocols": {
///     "ir": [{ "category": "tv", "name": "Tivi",
///              "brands": [{"brand":"samsung","name":"Samsung","count":58}] }],
///     "rf": [...] }}
/// ```
class CatalogIndex {
  const CatalogIndex({required this.protocols});

  factory CatalogIndex._parse(Map<String, dynamic> json) {
    final protoMap = json['protocols'] as Map<String, dynamic>? ?? {};
    final Map<String, List<CatalogCategoryEntry>> result = {};
    for (final entry in protoMap.entries) {
      result[entry.key] = (entry.value as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogCategoryEntry._fromJson)
          .toList();
    }
    return CatalogIndex(protocols: result);
  }

  /// Map: protocol → danh sách categories
  final Map<String, List<CatalogCategoryEntry>> protocols;

  List<CatalogCategoryEntry> categoriesFor(String protocol) =>
      protocols[protocol] ?? [];

  List<CatalogBrandEntry> brandsFor(String protocol, String category) {
    for (final cat in categoriesFor(protocol)) {
      if (cat.category == category) {
        final sorted = [...cat.brands.where((b) => b.brand != 'generic'),
                        ...cat.brands.where((b) => b.brand == 'generic')];
        return sorted;
      }
    }
    return [];
  }

  /// Tên hiển thị của category (từ server), fallback về key nếu không có.
  String categoryName(String protocol, String category) {
    for (final cat in categoriesFor(protocol)) {
      if (cat.category == category) return cat.name;
    }
    return category;
  }

  /// Tên hiển thị của brand (từ server), fallback về key nếu không có.
  String brandName(String protocol, String category, String brand) {
    for (final b in brandsFor(protocol, category)) {
      if (b.brand == brand) return b.name;
    }
    return brand;
  }
}

// ── Codeset Profile model ────────────────────────────────────────────────────

/// Một model trong catalog IR/RF codeset.
/// Parse từ DeviceProfile với naming convention: {proto}.{cat}.{brand}.{model_id}
class CodesetProfile {
  const CodesetProfile({
    required this.profileId,
    required this.profileName,
    required this.protocol,
    required this.category,
    required this.brand,
    required this.modelId,
    this.image,
    this.displayName,
    this.codesetMeta,
    this.buttonLayout = const [],
  });

  /// TB DeviceProfile entity ID (UUID)
  final String profileId;

  /// Profile name theo naming convention (vd: "ir.tv.samsung.generic")
  final String profileName;

  /// "ir" hoặc "rf"
  final String protocol;

  /// "tv" | "ac" | "fan" | "switch" | "curtain" | ...
  final String category;

  /// "samsung" | "lg" | "ev1527" | "generic" | ...
  final String brand;

  /// model_id từ tên (vd: "generic", "bn59_01199f")
  final String modelId;

  /// Ảnh remote (Base64 hoặc URL) — từ DeviceProfile.image
  final String? image;

  /// Tên hiển thị từ description.i18n.vi.name
  final String? displayName;

  /// Metadata codeset (year_range, models_hint) từ ui_hints.codeset
  final Map<String, dynamic>? codesetMeta;

  /// button_layout với proto — dùng để thử phím khi provisioning
  final List<Map<String, dynamic>> buttonLayout;

  /// Trả về danh sách nút thử (lọc các phím quan trọng: power, volUp, volDn, mute, on, off)
  List<Map<String, dynamic>> get testButtons {
    const testActions = {'power', 'volUp', 'volDn', 'mute', 'on', 'off', 'toggle'};
    final filtered = buttonLayout
        .where((b) => testActions.contains(b['action']))
        .toList();
    if (filtered.isNotEmpty) return filtered;
    // Fallback: lấy tối đa 4 nút đầu
    return buttonLayout.take(4).toList();
  }

  bool get isGeneric => modelId == 'generic';
}

// ── Codeset Service ──────────────────────────────────────────────────────────

/// Service fetch IR/RF Codeset dữ liệu từ ThingsBoard.
///
/// Luồng mới (2 bước):
///   1. [fetchCatalogIndex] → fetch profile "catalog" → trả về [CatalogIndex]
///      (index ~3KB: protocol→category→brand+count)
///   2. [fetchModels] → filter profiles theo {protocol}.{category}.{brand}.
///      (chỉ gọi khi user đã chọn brand)
class CodesetService {
  CodesetService()
      : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetch catalog index từ Device Profile "catalog" trên TB.
  /// Trả về [CatalogIndex] với hierarchy protocol→category→brand.
  Future<CatalogIndex> fetchCatalogIndex() async {
    // Tìm profile tên "catalog"
    final pageLink = PageLink(10, 0, 'catalog');
    final pageData =
        await _client.getDeviceProfileService().getDeviceProfileInfos(pageLink);
    final info =
        pageData.data.where((p) => p.name == 'catalog').firstOrNull;
    if (info == null) throw Exception('Catalog profile "catalog" không tìm thấy trên server');

    // Fetch full profile để lấy description
    final response = await _client
        .get<Map<String, dynamic>>('/api/deviceProfileInfo/${info.id.id}');
    final json = response.data;
    if (json == null) throw Exception('Không đọc được catalog profile');

    final descRaw = json['description'];
    Map<String, dynamic>? desc;
    if (descRaw is String && descRaw.isNotEmpty) {
      try {
        desc = jsonDecode(descRaw) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Catalog description không đúng định dạng JSON: $e');
      }
    } else if (descRaw is Map<String, dynamic>) {
      desc = descRaw;
    }
    if (desc == null) throw Exception('Catalog description rỗng');

    return CatalogIndex._parse(desc);
  }

  /// Fetch danh sách models cho protocol + category + brand cụ thể.
  /// Gọi API: GET /api/deviceProfileInfos?textSearch={p}.{c}.{b}.&pageSize=100
  Future<List<CodesetProfile>> fetchModels(
      String protocol, String category, String brand) {
    final prefix = '$protocol.$category.$brand.';
    return _fetchProfiles(prefix);
  }

  /// Fetch 1 profile cụ thể theo profile ID (TB entity ID).
  Future<CodesetProfile?> fetchProfile(String profileId) async {
    try {
      final response = await _client
          .get<Map<String, dynamic>>('/api/deviceProfileInfo/$profileId');
      final json = response.data;
      if (json == null) return null;
      return _parseProfileInfo(json);
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<CodesetProfile>> _fetchProfiles(String textSearch) async {
    final pageLink = PageLink(100, 0, textSearch);
    final pageData = await _client
        .getDeviceProfileService()
        .getDeviceProfileInfos(pageLink);

    final result = <CodesetProfile>[];
    for (final info in pageData.data) {
      if (!info.name.startsWith(textSearch)) continue;
      final parts = info.name.split('.');
      if (parts.length != 4) continue;

      CodesetProfile? profile;
      try {
        final response = await _client
            .get<Map<String, dynamic>>('/api/deviceProfileInfo/${info.id.id}');
        final rawJson = response.data;
        if (rawJson != null) profile = _parseProfileInfo(rawJson);
      } catch (_) {}

      profile ??= _parseProfileInfoFromSdk(info);
      if (profile != null) result.add(profile);
    }
    return result;
  }

  CodesetProfile? _parseProfileInfo(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final parts = name.split('.');
    if (parts.length != 4) return null;

    final profileId = (json['id'] as Map?)?.containsKey('id') == true
        ? (json['id'] as Map)['id'] as String? ?? ''
        : '';

    final image = json['image'] as String?;

    final descRaw = json['description'];
    Map<String, dynamic>? desc;
    if (descRaw is String && descRaw.isNotEmpty) {
      try {
        desc = jsonDecode(descRaw) as Map<String, dynamic>;
      } catch (_) {}
    } else if (descRaw is Map<String, dynamic>) {
      desc = descRaw;
    }

    String? displayName;
    List<Map<String, dynamic>> buttonLayout = [];
    Map<String, dynamic>? codesetMeta;

    if (desc != null) {
      displayName = ((desc['i18n'] as Map?)?['vi'] as Map?)?['name'] as String?;
      final uiHints = desc['ui_hints'] as Map?;
      if (uiHints != null) {
        final raw = uiHints['button_layout'];
        if (raw is List) {
          buttonLayout = raw
              .whereType<Map<String, dynamic>>()
              .where((b) => b.containsKey('proto'))
              .toList();
        }
        codesetMeta = uiHints['codeset'] as Map<String, dynamic>?;
      }
    }

    return CodesetProfile(
      profileId: profileId,
      profileName: name,
      protocol: parts[0],
      category: parts[1],
      brand: parts[2],
      modelId: parts[3],
      image: image,
      displayName: displayName,
      codesetMeta: codesetMeta,
      buttonLayout: buttonLayout,
    );
  }

  CodesetProfile? _parseProfileInfoFromSdk(DeviceProfileInfo info) {
    final name = info.name;
    final parts = name.split('.');
    if (parts.length != 4) return null;
    return CodesetProfile(
      profileId: info.id.id ?? '',
      profileName: name,
      protocol: parts[0],
      category: parts[1],
      brand: parts[2],
      modelId: parts[3],
      image: info.image,
    );
  }
}

// ── UI constants (UI-only, không phải data source) ───────────────────────────

/// Icon map cho category key — UI concern, không phụ thuộc catalog server.
const kCodesetCategoryIcons = <String, String>{
  'tv':        'tv',
  'ac':        'ac_unit',
  'fan':       'mode_fan',
  'stb':       'settings_input_hdmi',
  'projector': 'videocam',
  'switch':    'toggle_on',
  'curtain':   'blinds',
  'doorbell':  'doorbell',
  'gate':      'garage',
  'socket':    'power',
};

const kProtocolNames = <String, Map<String, String>>{
  'ir': {'vi': 'Hồng ngoại (IR)', 'en': 'Infrared (IR)'},
  'rf': {'vi': 'Sóng RF',         'en': 'RF Remote'},
};
