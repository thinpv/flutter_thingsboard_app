import 'package:flutter/foundation.dart';
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

  /// Resolves profile image + uiType parsed from its filename, keyed by
  /// profile ID only (no per-device work). Designed for the fast path where
  /// device server attributes (`ui_type`, `default_label`) come through a
  /// shared EntityDataQuery subscription instead of per-device REST.
  ///
  /// Uses an in-flight deduplication map so N rooms loading in parallel for
  /// the same profile ID result in exactly 1 network request, not N.
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
    final img = await _getProfileImage(profileId);
    final meta = DeviceUiMeta(uiType: _uiFromImage(img), profileImage: img);
    _profileMetaCache[profileId] = meta;
    return meta;
  }

  static final _profileMetaCache = <String, DeviceUiMeta>{};
  static final _inflightMeta = <String, Future<DeviceUiMeta>>{};
  static final _inflightImage = <String, Future<String?>>{};

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

  Future<String?> _getProfileImage(String profileId) {
    if (_profileImageCache.containsKey(profileId)) {
      return Future.value(_profileImageCache[profileId]);
    }
    return _inflightImage[profileId] ??=
        _fetchProfileImage(profileId).whenComplete(
      () => _inflightImage.remove(profileId),
    );
  }

  Future<String?> _fetchProfileImage(String profileId) async {
    try {
      final info = await _client
          .getDeviceProfileService()
          .getDeviceProfileInfo(profileId);
      String? image = info?.image;
      debugPrint('[DeviceProfileUiService] profileId=$profileId raw image=${image == null ? 'null' : image.substring(0, image.length.clamp(0, 60))}');
      // TB stores image as "tb-image;/api/images/..." — extract the URL part.
      if (image != null && image.startsWith('tb-image;')) {
        image = image.substring('tb-image;'.length);
      } else if (image != null && image.startsWith('data:')) {
        // Base64 data URI — cannot be used as CachedNetworkImage URL.
        debugPrint('[DeviceProfileUiService] profileId=$profileId image is base64 data URI, discarding');
        image = null;
      }
      debugPrint('[DeviceProfileUiService] profileId=$profileId resolved image=$image');
      _profileImageCache[profileId] = image;
      return image;
    } catch (e) {
      debugPrint('[DeviceProfileUiService] profileId=$profileId error: $e');
      _profileImageCache[profileId] = null;
      return null;
    }
  }

  static void clearCache() {
    _deviceCache.clear();
    _profileImageCache.clear();
    _profileMetaCache.clear();
    _inflightMeta.clear();
    _inflightImage.clear();
  }
}
