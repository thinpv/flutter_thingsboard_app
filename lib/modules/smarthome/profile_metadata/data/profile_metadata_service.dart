import 'dart:convert';

import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/data/profile_metadata_cache.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Service lấy [ProfileMetadata] cho một DeviceProfile.
///
/// Strategy: cache-first (Hive, TTL 24h) → fetch từ TB API.
///
/// Đọc `description` từ raw JSON của `/api/deviceProfileInfo/{id}` bằng HTTP
/// trực tiếp vì SDK `DeviceProfileInfo.fromJson` không parse field này.
class ProfileMetadataService {
  ProfileMetadataService({
    ProfileMetadataCache? cache,
    ITbClientService? tbClientService,
  })  : _cache = cache ?? ProfileMetadataCache.instance,
        _tbClient = (tbClientService ?? getIt<ITbClientService>()).client;

  final ProfileMetadataCache _cache;
  final ThingsboardClient _tbClient;

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Lấy [ProfileMetadata] cho [profileId].
  ///
  /// 1. Cache hit (còn TTL và không rỗng) → trả về ngay.
  /// 2. Cache miss → fetch raw JSON `/api/deviceProfileInfo/{id}` → parse
  ///    `description` → lưu cache nếu không rỗng → trả về.
  /// 3. Nếu fetch lỗi hoặc description không có → trả về `ProfileMetadata()`
  ///    (empty, không throw).
  Future<ProfileMetadata> getForProfile(String? profileId) async {
    if (profileId == null || profileId.isEmpty) {
      return const ProfileMetadata();
    }

    // 1. Cache hit — chỉ dùng nếu metadata không rỗng (tránh serve stale
    // empty entries được cache từ trước khi description có dữ liệu).
    final cached = await _cache.get(profileId);
    if (cached != null && !cached.isEmpty) return cached;

    // 2. Fetch raw JSON để đọc được field `description`
    // (SDK DeviceProfileInfo.fromJson không parse description).
    try {
      final response = await _tbClient
          .get<Map<String, dynamic>>('/api/deviceProfileInfo/$profileId');
      final json = response.data;
      if (json == null) return const ProfileMetadata();

      // description có thể là JSON string hoặc Map (tùy TB version)
      final descRaw = json['description'];
      String? descJson;
      if (descRaw is String && descRaw.isNotEmpty) {
        descJson = descRaw;
      } else if (descRaw is Map<String, dynamic>) {
        descJson = jsonEncode(descRaw);
      }

      final metadata = ProfileMetadata.tryParse(descJson);
      // Chỉ cache khi có nội dung thực sự — tránh cache empty rồi không
      // bao giờ fetch lại khi profile được cập nhật.
      if (!metadata.isEmpty) {
        await _cache.put(profileId, metadata);
      }
      return metadata;
    } catch (_) {
      return const ProfileMetadata();
    }
  }

  /// Xóa cache của một profile cụ thể, buộc fetch lại lần sau.
  Future<void> invalidate(String profileId) async {
    await _cache.remove(profileId);
  }

  /// Xóa toàn bộ cache.
  Future<void> invalidateAll() async {
    await _cache.clear();
  }

  /// Preload metadata cho danh sách profileId (batch, parallel).
  Future<void> preload(List<String> profileIds) async {
    if (profileIds.isEmpty) return;
    final unique = profileIds.toSet().toList();
    await Future.wait(unique.map(getForProfile));
  }
}
