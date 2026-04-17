// A-A-11: Integration test — mock TB client → fetch profile → parse metadata → verify field mapping
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/data/profile_metadata_cache.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class MockProfileMetadataCache extends Mock implements ProfileMetadataCache {}

// ─── Fake TB layer ────────────────────────────────────────────────────────────

class _FakeDeviceProfileInfo {
  _FakeDeviceProfileInfo({this.description});
  final String? description;
}

typedef _ProfileInfoFetcher = Future<_FakeDeviceProfileInfo?> Function(String id);

class _FakeDeviceProfileService {
  _FakeDeviceProfileService(this._fetch);
  final _ProfileInfoFetcher _fetch;
  Future<_FakeDeviceProfileInfo?> getDeviceProfileInfo(String id) => _fetch(id);
}

class _FakeTbClient {
  _FakeTbClient(this._service);
  final _FakeDeviceProfileService _service;
  _FakeDeviceProfileService getDeviceProfileService() => _service;
}

_FakeTbClient makeFakeClient(Map<String, _FakeDeviceProfileInfo?> infos) {
  return _FakeTbClient(
    _FakeDeviceProfileService((id) async => infos[id]),
  );
}

_FakeTbClient makeThrowingClient() {
  return _FakeTbClient(
    _FakeDeviceProfileService((_) async => throw Exception('Network error')),
  );
}

// ─── Testable service (no getIt dependency) ───────────────────────────────────

class _TestableService {
  _TestableService({required this.cache, required _FakeTbClient fakeClient})
      : _fakeClient = fakeClient;

  final ProfileMetadataCache cache;
  final _FakeTbClient _fakeClient;

  Future<ProfileMetadata> getForProfile(String? profileId) async {
    if (profileId == null || profileId.isEmpty) return const ProfileMetadata();
    final cached = await cache.get(profileId);
    if (cached != null) return cached;
    try {
      final info = await _fakeClient
          .getDeviceProfileService()
          .getDeviceProfileInfo(profileId);
      final metadata = ProfileMetadata.tryParse(info?.description);
      await cache.put(profileId, metadata);
      return metadata;
    } catch (_) {
      return const ProfileMetadata();
    }
  }

  Future<void> invalidate(String profileId) => cache.remove(profileId);

  Future<void> preload(List<String> profileIds) async {
    final unique = profileIds.toSet().toList();
    await Future.wait(unique.map(getForProfile), eagerError: false);
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(const ProfileMetadata());
  });

  late MockProfileMetadataCache mockCache;

  const profileId = 'profile-uuid-001';
  const smartPlugDescription = '''
{
  "v": 1,
  "ui_type": "smartPlug",
  "icon": "power",
  "states": {
    "onoff0": {"type": "bool", "controllable": true},
    "power":  {"type": "number", "unit": "W", "chartable": true}
  },
  "actions": {"toggle": {"params_hint": []}}
}''';

  setUp(() {
    mockCache = MockProfileMetadataCache();
    when(() => mockCache.isReady).thenReturn(true);
    // Default stubs — individual tests override as needed
    when(() => mockCache.get(any())).thenAnswer((_) async => null);
    when(() => mockCache.put(any(), any())).thenAnswer((_) async {});
    when(() => mockCache.remove(any())).thenAnswer((_) async {});
    when(() => mockCache.clear()).thenAnswer((_) async {});
  });

  group('cache hit', () {
    test('returns cached metadata without calling TB', () async {
      final cachedMeta = ProfileMetadata.tryParse(smartPlugDescription);
      when(() => mockCache.get(profileId)).thenAnswer((_) async => cachedMeta);

      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeFakeClient({}),
      );

      final result = await service.getForProfile(profileId);

      expect(result.uiType, 'smartPlug');
      expect(result.states['onoff0']?.controllable, isTrue);
      verifyNever(() => mockCache.put(profileId, any()));
    });
  });

  group('cache miss — TB fetch', () {
    test('fetches DeviceProfileInfo, parses description, caches result', () async {
      // Default stubs from setUp handle get → null and put → void
      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeFakeClient({
          profileId: _FakeDeviceProfileInfo(description: smartPlugDescription),
        }),
      );

      final result = await service.getForProfile(profileId);

      expect(result.uiType, 'smartPlug');
      expect(result.icon, 'power');
      expect(result.states.length, 2);
      expect(result.states['power']?.unit, 'W');
      expect(result.actions['toggle']?.paramsHint, isEmpty);

      final captured =
          verify(() => mockCache.put(profileId, captureAny())).captured.first
              as ProfileMetadata;
      expect(captured.uiType, 'smartPlug');
    });

    test('returns empty when description is null (backend chưa patch)', () async {

      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeFakeClient({
          profileId: _FakeDeviceProfileInfo(description: null),
        }),
      );

      final result = await service.getForProfile(profileId);
      expect(result.isEmpty, isTrue);
      verify(() => mockCache.put(profileId, any())).called(1);
    });

    test('returns empty for null profileId, no cache calls', () async {
      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeFakeClient({}),
      );
      final result = await service.getForProfile(null);
      expect(result.isEmpty, isTrue);
      verifyNever(() => mockCache.get(any()));
    });

    test('returns empty and does not throw when TB throws', () async {
      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeThrowingClient(),
      );

      final result = await service.getForProfile(profileId);
      expect(result.isEmpty, isTrue);
      verifyNever(() => mockCache.put(any(), any()));
    });
  });

  group('invalidate + preload', () {
    test('invalidate removes cache entry', () async {
      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeFakeClient({}),
      );
      await service.invalidate(profileId);
      verify(() => mockCache.remove(profileId)).called(1);
    });

    test('preload fetches all unique profileIds once', () async {
      const ids = ['id1', 'id2', 'id3', 'id1']; // id1 duplicate
      // Default stubs from setUp: get → null, put → void
      final service = _TestableService(
        cache: mockCache,
        fakeClient: makeFakeClient({
          'id1': _FakeDeviceProfileInfo(description: '{"ui_type":"light"}'),
          'id2': _FakeDeviceProfileInfo(description: '{"ui_type":"sensor"}'),
          'id3': _FakeDeviceProfileInfo(description: null),
        }),
      );

      await service.preload(ids);

      verify(() => mockCache.get('id1')).called(1);
      verify(() => mockCache.get('id2')).called(1);
      verify(() => mockCache.get('id3')).called(1);
    });
  });
}
