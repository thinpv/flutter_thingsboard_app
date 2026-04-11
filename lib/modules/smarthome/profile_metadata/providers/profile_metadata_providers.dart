import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/data/profile_metadata_service.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

/// Singleton service provider.
///
/// Dùng `getIt` nội bộ để lấy ThingsboardClient và cache — không cần inject.
final profileMetadataServiceProvider = Provider<ProfileMetadataService>((ref) {
  return ProfileMetadataService();
});

/// Lấy [ProfileMetadata] cho một profileId cụ thể.
///
/// Cache-first (TTL 24h). Trả về `ProfileMetadata()` (empty) nếu:
/// - profileId null/rỗng
/// - Backend chưa deploy patch A-S-2 (description chưa có)
/// - Parse lỗi
///
/// Usage:
/// ```dart
/// final metaAsync = ref.watch(profileMetadataProvider('profile-uuid'));
/// ```
final profileMetadataProvider =
    FutureProvider.family<ProfileMetadata, String>((ref, profileId) {
  final service = ref.read(profileMetadataServiceProvider);
  return service.getForProfile(profileId);
});

/// Lấy [ProfileMetadata] cho một device qua [SmarthomeDevice.deviceProfileId].
///
/// Trả về empty nếu device không có profileId.
///
/// Usage:
/// ```dart
/// final metaAsync = ref.watch(deviceProfileMetadataProvider(device.deviceProfileId ?? ''));
/// ```
final deviceProfileMetadataProvider =
    FutureProvider.family<ProfileMetadata, String>((ref, profileId) {
  if (profileId.isEmpty) return Future.value(const ProfileMetadata());
  return ref.read(profileMetadataServiceProvider).getForProfile(profileId);
});
