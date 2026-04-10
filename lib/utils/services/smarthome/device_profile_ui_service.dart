import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// UI metadata for a device: ui_type + image URL + default label.
class DeviceUiMeta {
  const DeviceUiMeta({this.uiType, this.defaultLabel, this.profileImage});

  final String? uiType;
  final String? defaultLabel;

  /// Profile image URL (e.g. "/api/images/tenant/ui_light.png").
  final String? profileImage;

  static const empty = DeviceUiMeta();
}

/// Resolves device UI metadata.
///
/// uiType resolution chain:
///   1. Device SERVER_SCOPE attribute `ui_type` (per-device override)
///   2. Filename of the profile image: `ui_{type}[__{imgname}].(png|svg|…)`
///   3. null → generic widget
class DeviceProfileUiService {
  DeviceProfileUiService() : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  /// Cache: device ID → metadata.
  static final _deviceCache = <String, DeviceUiMeta>{};

  /// Cache: profile ID → image URL.
  static final _profileImageCache = <String, String?>{};

  /// Parses uiType from the profile image URL. Returns null if the image does
  /// not follow the `ui_{type}[__{imgname}].ext` convention, or if the type
  /// token is `generic`.
  static final _imgTypeRx =
      RegExp(r'/ui_([a-z_]+?)(?:__[^/]*)?\.(?:png|svg|jpg|jpeg|webp)$');

  static String? _uiFromImage(String? image) {
    if (image == null) return null;
    final m = _imgTypeRx.firstMatch(image);
    final token = m?.group(1);
    if (token == null || token == 'generic') return null;
    return token;
  }

  Future<DeviceUiMeta> getUiMeta(
    String deviceId,
    String? profileId,
  ) async {
    final cached = _deviceCache[deviceId];
    if (cached != null) return cached;

    String? uiType;
    String? defaultLabel;

    // 1. Device-level override + label from attributes.
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

    // 2. Profile image (cached per profile ID) + uiType parsed from its URL.
    String? profileImage;
    if (profileId != null) {
      profileImage = await _getProfileImage(profileId);
    }

    final resolvedUiType = uiType ?? _uiFromImage(profileImage);

    final meta = DeviceUiMeta(
      uiType: resolvedUiType,
      defaultLabel: defaultLabel,
      profileImage: profileImage,
    );
    _deviceCache[deviceId] = meta;
    return meta;
  }

  Future<String?> _getProfileImage(String profileId) async {
    if (_profileImageCache.containsKey(profileId)) {
      return _profileImageCache[profileId];
    }
    try {
      final info = await _client
          .getDeviceProfileService()
          .getDeviceProfileInfo(profileId);
      String? image = info?.image;
      // TB stores image as "tb-image;/api/images/..." — extract the URL part.
      if (image != null && image.startsWith('tb-image;')) {
        image = image.substring('tb-image;'.length);
      }
      _profileImageCache[profileId] = image;
      return image;
    } catch (_) {
      _profileImageCache[profileId] = null;
      return null;
    }
  }

  static void clearCache() {
    _deviceCache.clear();
    _profileImageCache.clear();
  }
}
