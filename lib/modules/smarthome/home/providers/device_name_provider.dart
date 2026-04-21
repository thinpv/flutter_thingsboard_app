import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/utils/services/smarthome/device_profile_ui_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Resolves the display name for a device by ID using the same 3-level priority
/// as [SmarthomeDevice.displayName]:
///   1. TB device `label`       (user-set)
///   2. Profile `description.i18n.vi.name`  (descriptor)
///   3. TB device `name`        (raw identifier fallback)
///
/// Uses the same [DeviceProfileUiService] cache as the home screen, so
/// profile metadata lookups are free when the home tab has already loaded.
final deviceDisplayNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, deviceId) async {
  final client = getIt<ITbClientService>().client;

  final device = await client.getDeviceService().getDevice(deviceId);
  if (device == null) return deviceId;

  // Priority 1: TB device label
  final label = device.label;
  if (label != null && label.isNotEmpty) return label;

  // Priority 2: profile descriptor name (cached; nearly free if home tab loaded)
  final profileId = device.deviceProfileId?.id;
  final profileName =
      (await DeviceProfileUiService().getProfileMeta(profileId)).profileName;
  if (profileName != null && profileName.isNotEmpty) return profileName;

  // Priority 3: raw device name
  return device.name;
});
