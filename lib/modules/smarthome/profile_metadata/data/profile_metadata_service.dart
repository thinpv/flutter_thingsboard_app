import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thingsboard_app/constants/app_constants.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/data/profile_metadata_cache.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

/// Service lấy [ProfileMetadata] cho một DeviceProfile.
///
/// Strategy: cache-first (Hive, TTL 24h) → fetch từ TB API.
/// Sau khi backend deploy patch A-S-2, `DeviceProfileInfo.description`
/// sẽ chứa JSON metadata; `ProfileMetadata.tryParse` xử lý tolerant.
class ProfileMetadataService {
  ProfileMetadataService({
    ProfileMetadataCache? cache,
    ITbClientService? tbClientService,
  })  : _cache = cache ?? ProfileMetadataCache.instance,
        _tbClient = (tbClientService ?? getIt<ITbClientService>()).client;

  final ProfileMetadataCache _cache;
  final dynamic _tbClient; // ThingsboardClient

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Lấy [ProfileMetadata] cho [profileId].
  ///
  /// 1. Cache hit (không hết TTL) → trả về ngay.
  /// 2. Cache miss → fetch `DeviceProfileInfo` từ TB → parse description →
  ///    lưu vào cache → trả về.
  /// 3. Nếu fetch lỗi → trả về `ProfileMetadata()` (empty, không throw).
  Future<ProfileMetadata> getForProfile(String? profileId) async {
    if (profileId == null || profileId.isEmpty) {
      return const ProfileMetadata();
    }

    // 1. Cache hit
    final cached = await _cache.get(profileId);
    if (cached != null) return cached;

    // 2. Fetch raw JSON trực tiếp — SDK class DeviceProfileInfo.fromJson không
    //    parse field `description` nên phải đọc từ raw response.
    try {
      final token = _tbClient.getJwtToken() ?? '';
      final baseUrl = ThingsboardAppConstants.thingsBoardApiEndpoint;
      final resp = await http.get(
        Uri.parse('$baseUrl/api/deviceProfileInfo/$profileId'),
        headers: {'X-Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final description = json['description'] as String?;
        final metadata = ProfileMetadata.tryParse(description);
        // Chỉ cache khi parse được data thực sự.
        if (!metadata.isEmpty) {
          await _cache.put(profileId, metadata);
        }
        return metadata;
      }
    } catch (_) {}
    return const ProfileMetadata();
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
  ///
  /// Dùng khi app khởi động, chủ động warm-up cache trước khi user
  /// mở detail page. Profile đã cache và còn TTL sẽ được bỏ qua.
  Future<void> preload(List<String> profileIds) async {
    if (profileIds.isEmpty) return;
    final unique = profileIds.toSet().toList();
    await Future.wait(
      unique.map(getForProfile),
      eagerError: false,
    );
  }
}
