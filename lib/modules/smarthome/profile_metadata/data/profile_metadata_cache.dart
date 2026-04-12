import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

/// Hive-backed cache cho [ProfileMetadata] với TTL 24 giờ.
///
/// Lưu trữ: `Box<String>` tên 'profile_metadata_cache'.
/// Value là JSON string encode của `{json: String, ts: int}`.
///
/// Sử dụng:
/// ```dart
/// await ProfileMetadataCache.instance.init();
/// final meta = await ProfileMetadataCache.instance.get(profileId);
/// await ProfileMetadataCache.instance.put(profileId, meta);
/// ```
class ProfileMetadataCache {
  ProfileMetadataCache._();

  static final instance = ProfileMetadataCache._();

  static const _boxName = 'profile_metadata_cache';
  static const _imageBoxName = 'profile_image_cache';
  static const _ttlMs = 24 * 60 * 60 * 1000; // 24 giờ

  Box<String>? _box;
  Box<String>? _imageBox;

  bool get isReady => _box != null && _box!.isOpen;

  Future<void> init() async {
    if (isReady) return;
    _box = await Hive.openBox<String>(_boxName);
    _imageBox = await Hive.openBox<String>(_imageBoxName);
  }

  Future<void> close() async {
    await _box?.close();
    await _imageBox?.close();
    _box = null;
    _imageBox = null;
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────

  /// Lấy [ProfileMetadata] từ cache. Trả về null nếu không có hoặc đã hết TTL.
  Future<ProfileMetadata?> get(String profileId) async {
    if (!isReady) return null;
    final raw = _box!.get(profileId);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final ts = entry['ts'] as int;
      if (DateTime.now().millisecondsSinceEpoch - ts > _ttlMs) {
        await _box!.delete(profileId);
        return null;
      }
      final dataJson = entry['data'] as String?;
      return ProfileMetadata.tryParse(dataJson);
    } catch (_) {
      // Entry bị corrupt — xóa đi
      await _box!.delete(profileId);
      return null;
    }
  }

  /// Lưu [ProfileMetadata] vào cache, gắn timestamp hiện tại.
  Future<void> put(String profileId, ProfileMetadata metadata) async {
    if (!isReady) return;
    final entry = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'data': jsonEncode(metadata.toJson()),
    });
    await _box!.put(profileId, entry);
  }

  /// Xóa một entry theo profileId.
  Future<void> remove(String profileId) async {
    if (!isReady) return;
    await _box!.delete(profileId);
  }

  /// Xóa toàn bộ cache.
  Future<void> clear() async {
    if (!isReady) return;
    await _box!.clear();
    await _imageBox?.clear();
  }

  // ─── Image URL cache ─────────────────────────────────────────────────────

  /// Lấy image URL (đã strip prefix "tb-image;") cho profileId.
  /// Trả về null nếu chưa cache.
  Future<String?> getImage(String profileId) async {
    return _imageBox?.get(profileId);
  }

  /// Lưu image URL vào cache (không TTL — profile image thay đổi rất ít).
  Future<void> putImage(String profileId, String imageUrl) async {
    await _imageBox?.put(profileId, imageUrl);
  }

  /// Xóa image cache của một profile.
  Future<void> removeImage(String profileId) async {
    await _imageBox?.delete(profileId);
  }

  /// Trả về map profileId → hash (Dart hashCode của raw JSON string).
  /// Dùng để phát hiện thay đổi mà không cần deserialize.
  Map<String, String> allHashes() {
    if (!isReady) return const {};
    final result = <String, String>{};
    for (final key in _box!.keys) {
      final raw = _box!.get(key as String);
      if (raw != null) {
        result[key] = raw.hashCode.toRadixString(16);
      }
    }
    return result;
  }

  /// Số entry đang cache (kể cả đã hết TTL chưa được dọn).
  int get length => _box?.length ?? 0;
}
