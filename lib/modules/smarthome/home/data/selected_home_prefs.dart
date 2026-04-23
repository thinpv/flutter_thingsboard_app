import 'package:hive_flutter/hive_flutter.dart';

/// Persists the last-selected home ID across app restarts.
class SelectedHomePrefs {
  SelectedHomePrefs._();
  static final instance = SelectedHomePrefs._();

  static const _boxName = 'home_prefs';
  static const _key = 'selectedHomeId';

  Box<String>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  String? getSelectedHomeId() => _box?.get(_key);

  Future<void> setSelectedHomeId(String id) async {
    await _box?.put(_key, id);
  }

  Future<void> clear() async {
    await _box?.delete(_key);
  }
}
