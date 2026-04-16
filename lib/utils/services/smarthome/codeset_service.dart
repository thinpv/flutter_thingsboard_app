import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

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

/// Kết quả phân tích catalog theo từng tầng
class CodesetCatalog {
  const CodesetCatalog({required this.profiles});

  /// Tất cả profiles đã fetch
  final List<CodesetProfile> profiles;

  /// Danh sách category (tầng 2) theo protocol
  List<String> categoriesFor(String protocol) {
    final cats = <String>{};
    for (final p in profiles) {
      if (p.protocol == protocol) cats.add(p.category);
    }
    final sorted = cats.toList()..sort();
    return sorted;
  }

  /// Danh sách brand (tầng 3) theo protocol + category
  List<String> brandsFor(String protocol, String category) {
    final brands = <String>{};
    for (final p in profiles) {
      if (p.protocol == protocol && p.category == category) {
        brands.add(p.brand);
      }
    }
    final sorted = brands.toList()..sort();
    // Đẩy "generic" xuống cuối
    if (sorted.remove('generic')) sorted.add('generic');
    return sorted;
  }

  /// Danh sách models (tầng 4) theo protocol + category + brand
  List<CodesetProfile> modelsFor(String protocol, String category, String brand) {
    final models = profiles
        .where((p) =>
            p.protocol == protocol &&
            p.category == category &&
            p.brand == brand)
        .toList();
    // "generic" model xuống cuối
    models.sort((a, b) {
      if (a.isGeneric && !b.isGeneric) return 1;
      if (!a.isGeneric && b.isGeneric) return -1;
      return a.modelId.compareTo(b.modelId);
    });
    return models;
  }
}

/// Service fetch và parse IR/RF Codeset Profiles từ ThingsBoard.
///
/// Dùng API: GET /api/deviceProfileInfos?textSearch={prefix}&pageSize=1000
/// Tất cả codeset profiles theo naming convention {proto}.{cat}.{brand}.{model}
/// → Customer user có quyền đọc DeviceProfileInfo (name, image, description).
class CodesetService {
  CodesetService()
      : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetch tất cả profiles cho 1 protocol prefix ("ir." hoặc "rf.").
  /// Parse naming convention → trả về [CodesetCatalog].
  Future<CodesetCatalog> fetchCatalog(String protocol) async {
    assert(protocol == 'ir' || protocol == 'rf');
    final prefix = '$protocol.';
    final profiles = await _fetchProfiles(prefix);
    return CodesetCatalog(profiles: profiles);
  }

  /// Fetch 1 profile cụ thể theo profile ID (TB entity ID).
  /// Đọc full description để lấy button_layout + proto.
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
    final pageLink = PageLink(1000, 0, textSearch);
    final pageData = await _client
        .getDeviceProfileService()
        .getDeviceProfileInfos(pageLink);

    final result = <CodesetProfile>[];
    for (final info in pageData.data) {
      // Lọc đúng naming convention (textSearch có thể khớp cả tên khác)
      if (!info.name.startsWith(textSearch)) continue;
      final parts = info.name.split('.');
      if (parts.length != 4) continue;

      // Đọc description từ raw API để lấy button_layout
      CodesetProfile? profile;
      try {
        final response = await _client
            .get<Map<String, dynamic>>('/api/deviceProfileInfo/${info.id.id}');
        final rawJson = response.data;
        if (rawJson != null) {
          profile = _parseProfileInfo(rawJson);
        }
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

    // description: có thể là String (JSON-encoded) hoặc Map
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
      // Display name: i18n.vi.name
      displayName = (desc['i18n'] as Map?)
          ?['vi']?['name'] as String?;

      // button_layout
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

// ── Display name lookup tables ──────────────────────────────────────────────

const kCodesetCategoryNames = <String, Map<String, String>>{
  // IR categories
  'tv':        {'vi': 'Tivi',           'en': 'TV'},
  'ac':        {'vi': 'Điều hòa',       'en': 'Air Conditioner'},
  'fan':       {'vi': 'Quạt',           'en': 'Fan'},
  'stb':       {'vi': 'Đầu thu',        'en': 'Set-top Box'},
  'projector': {'vi': 'Máy chiếu',      'en': 'Projector'},
  // RF categories
  'switch':    {'vi': 'Công tắc',       'en': 'Switch'},
  'curtain':   {'vi': 'Rèm',            'en': 'Curtain'},
  'doorbell':  {'vi': 'Chuông cửa',     'en': 'Doorbell'},
  'gate':      {'vi': 'Cổng/Cửa cuốn', 'en': 'Gate/Roller'},
  // Dùng chung
  'socket':    {'vi': 'Ổ cắm',         'en': 'Socket'},
};

const kCodesetBrandNames = <String, String>{
  'samsung':    'Samsung',
  'lg':         'LG',
  'daikin':     'Daikin',
  'panasonic':  'Panasonic',
  'toshiba':    'Toshiba',
  'sony':       'Sony',
  'sharp':      'Sharp',
  'mitsubishi': 'Mitsubishi',
  'carrier':    'Carrier',
  'midea':      'Midea',
  'gree':       'Gree',
  'ev1527':     'EV1527',
  'pt2262':     'PT2262',
  'dooya':      'Dooya',
  'somfy':      'Somfy',
  'generic':    'Khác',
};

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

String categoryDisplayName(String cat, {String lang = 'vi'}) {
  return kCodesetCategoryNames[cat]?[lang] ?? cat;
}

String brandDisplayName(String brand) {
  return kCodesetBrandNames[brand] ?? brand;
}
