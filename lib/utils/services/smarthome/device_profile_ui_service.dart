import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// UI metadata for a device: ui_type + image URL + profile name + default label.
class DeviceUiMeta {
  const DeviceUiMeta({
    this.uiType,
    this.defaultLabel,
    this.profileImage,
    this.profileName,
  });

  final String? uiType;
  final String? defaultLabel;

  /// Profile image URL (e.g. "/api/images/tenant/ui_smart_plug__ZNCZ02LM.png").
  final String? profileImage;

  /// Localized device type name from profile description i18n.
  /// e.g. "Ổ cắm thông minh" (from i18n.vi.name).
  final String? profileName;

  static const empty = DeviceUiMeta();
}

/// Resolves device profile UI metadata — image URL and basics for the device stream.
///
/// This service handles the per-profile REST fetch that cannot live in a
/// Riverpod provider (it runs inside a raw Stream, not a widget tree).
///
/// For full metadata (states, actions, ui_hints) use [ProfileMetadataService]
/// via `deviceProfileMetadataProvider` inside widgets.
class DeviceProfileUiService {
  DeviceProfileUiService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  /// Cache: device ID → metadata.
  static final _deviceCache = <String, DeviceUiMeta>{};

  /// Cache: profile ID → full UI metadata (image + uiType + profileName).
  static final _profileMetaCache = <String, DeviceUiMeta>{};

  /// In-flight deduplication for profile meta fetches.
  static final _inflightMeta = <String, Future<DeviceUiMeta>>{};

  /// Resolves profile image, uiType, and localized profileName for a profile ID.
  ///
  /// - `profileImage` : from `DeviceProfileInfo.image` (TB REST)
  /// - `uiType`       : from `description.ui_type` → fallback image-filename hack
  /// - `profileName`  : from `description.i18n.vi.name` (or en)
  ///
  /// Uses in-flight deduplication: 400 devices sharing 20 profiles → 20 requests.
  Future<DeviceUiMeta> getProfileMeta(String? profileId) {
    if (profileId == null) return Future.value(DeviceUiMeta.empty);
    final cached = _profileMetaCache[profileId];
    if (cached != null) return Future.value(cached);
    return _inflightMeta[profileId] ??=
        _fetchProfileMeta(profileId).whenComplete(
      () => _inflightMeta.remove(profileId),
    );
  }

  Future<DeviceUiMeta> _fetchProfileMeta(String profileId) async {
    String? img;
    String? uiType;
    String? profileName;

    try {
      // Use raw HTTP so we get the `description` field.
      // SDK DeviceProfileInfo.fromJson does NOT parse description.
      final response = await _client.get<Map<String, dynamic>>(
        '/api/deviceProfileInfo/$profileId',
      );
      final json = response.data;
      if (json != null) {
        img = json['image'] as String?;

        // Parse description with ProfileMetadata.tryParse (handles both
        // JSON-string and JSON-object formats, tolerant on parse errors).
        final meta = ProfileMetadata.tryParse(json['description'] as String?);
        if (!meta.isEmpty) {
          uiType = meta.uiType == 'auto' ? null : meta.uiType;
          profileName = meta.localizedName('vi');
        }
      }
    } catch (_) {}

    // Strip tb-image; prefix.
    if (img != null && img.startsWith('tb-image;')) {
      img = img.substring('tb-image;'.length);
    }

    // Fall back to image-filename convention if description.ui_type not set.
    uiType ??= _uiFromImage(img);

    final result = DeviceUiMeta(
      uiType: uiType,
      profileImage: img,
      profileName: profileName,
    );
    _profileMetaCache[profileId] = result;
    return result;
  }

  /// Resolves per-device UI metadata — server attr overrides take priority.
  ///
  /// Used by the "scan devices" page which needs per-device REST calls anyway.
  /// For the home screen stream, `getProfileMeta` is preferred (faster, per-profile).
  Future<DeviceUiMeta> getUiMeta(
    String deviceId,
    String? profileId,
  ) async {
    final cached = _deviceCache[deviceId];
    if (cached != null) return cached;

    String? uiType;
    String? defaultLabel;

    // 1. Device-level server attribute overrides.
    try {
      final serverAttrs = await _client
          .getAttributeService()
          .getAttributesByScope(
            DeviceId(deviceId),
            'SERVER_SCOPE',
            ['ui_type', 'default_label'],
          );
      for (final attr in serverAttrs) {
        if (attr.getKey() == 'ui_type') uiType = attr.getValue()?.toString();
        if (attr.getKey() == 'default_label') {
          defaultLabel = attr.getValue()?.toString();
        }
      }
    } catch (_) {}

    // 2. Fallback: client attribute `name` set by gateway on provision.
    if (defaultLabel == null) {
      try {
        final clientAttrs = await _client
            .getAttributeService()
            .getAttributesByScope(
              DeviceId(deviceId),
              'CLIENT_SCOPE',
              ['name'],
            );
        for (final attr in clientAttrs) {
          if (attr.getKey() == 'name') {
            defaultLabel = attr.getValue()?.toString();
          }
        }
      } catch (_) {}
    }

    // 3. Profile-level metadata (image + uiType fallback + profileName).
    final profileMeta = await getProfileMeta(profileId);

    final result = DeviceUiMeta(
      uiType: uiType ?? profileMeta.uiType,
      defaultLabel: defaultLabel,
      profileImage: profileMeta.profileImage,
      profileName: profileMeta.profileName,
    );
    _deviceCache[deviceId] = result;
    return result;
  }

  static void clearCache() {
    _deviceCache.clear();
    _profileMetaCache.clear();
    _inflightMeta.clear();
  }

  // ─── Legacy image-filename convention ─────────────────────────────────────

  static final _imgTypeRx =
      RegExp(r'/ui_([a-z_]+?)(?:__[^/]*)?\.(?:png|svg|jpg|jpeg|webp)$');

  static String? _uiFromImage(String? image) {
    if (image == null) return null;
    final m = _imgTypeRx.firstMatch(image);
    final token = m?.group(1);
    if (token == null || token == 'generic') return null;
    return token;
  }
}
