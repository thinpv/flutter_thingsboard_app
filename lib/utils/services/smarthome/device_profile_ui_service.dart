import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// UI metadata for a device: ui_type from server attr + image from profile.
class DeviceUiMeta {
  const DeviceUiMeta({this.uiType, this.defaultLabel, this.profileImage});

  final String? uiType;
  final String? defaultLabel;

  /// Profile image URL (e.g. "/api/images/tenant/xxx.png").
  final String? profileImage;

  static const empty = DeviceUiMeta();
}

/// Reads device UI metadata: ui_type from server attributes,
/// profile image from DeviceProfileInfo.
class DeviceProfileUiService {
  DeviceProfileUiService()
      : _client = getIt<ITbClientService>().client;

  final ThingsboardClient _client;

  /// Cache: device ID → metadata.
  static final _deviceCache = <String, DeviceUiMeta>{};

  /// Cache: profile ID → image URL.
  static final _profileImageCache = <String, String?>{};

  /// Resolves ui_type (server attr) + profile image for a device.
  Future<DeviceUiMeta> getUiMeta(String deviceId, String? profileId) async {
    final cached = _deviceCache[deviceId];
    if (cached != null) return cached;

    String? uiType;
    String? defaultLabel;

    // 1. Read ui_type from device server attributes
    try {
      final attrs = await _client.getAttributeService().getAttributesByScope(
            DeviceId(deviceId),
            'SERVER_SCOPE',
            ['ui_type', 'default_label'],
          );
      for (final attr in attrs) {
        if (attr.getKey() == 'ui_type') uiType = attr.getValue()?.toString();
        if (attr.getKey() == 'default_label') {
          defaultLabel = attr.getValue()?.toString();
        }
      }
    } catch (_) {}

    // 2. Read profile image (cached per profile ID)
    String? profileImage;
    if (profileId != null) {
      profileImage = await _getProfileImage(profileId);
    }

    final meta = DeviceUiMeta(
      uiType: uiType,
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
      // TB stores image as "tb-image;/api/images/..." — extract the URL part
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
