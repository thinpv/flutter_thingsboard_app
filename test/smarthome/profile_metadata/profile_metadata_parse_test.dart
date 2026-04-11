// A-A-9: Unit test ProfileMetadata.tryParse — valid / missing / corrupted / future-version
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';

void main() {
  group('ProfileMetadata.tryParse', () {
    // ── valid ──────────────────────────────────────────────────────────────

    test('parses full smart_plug description', () {
      const description = '''
{
  "v": 1,
  "ui_type": "smart_plug",
  "icon": "power",
  "color_primary": "#4CAF50",
  "states": {
    "onoff0": {"type": "bool", "controllable": true, "label_default": "Bật/Tắt"},
    "power":  {"type": "number", "unit": "W", "range": {"min": 0, "max": 3000},
               "precision": 1, "chartable": true, "label_default": "Công suất"},
    "energy": {"type": "number", "unit": "kWh", "cumulative": true,
               "chartable": true, "precision": 3, "label_default": "Điện năng"}
  },
  "actions": {
    "setValue": {"params_hint": ["onoff0"]},
    "toggle":   {"params_hint": []}
  },
  "ui_hints": {
    "primary_state": "onoff0",
    "summary_states": ["power", "energy"],
    "card_layout": "toggle_with_metrics",
    "max_power": 3000,
    "chart_keys": ["power", "energy"],
    "quick_actions": [
      {"method": "toggle", "label": "Bật/Tắt", "icon": "power_settings_new"}
    ]
  },
  "automation": {
    "conditions": [
      {"key": "onoff0", "ops": ["==","!="]},
      {"key": "power",  "ops": [">","<",">=","<=","<>"]}
    ],
    "actions": [
      {"method": "setValue", "param": "onoff0"},
      {"method": "toggle"}
    ]
  },
  "i18n": {
    "vi": {"name": "Ổ cắm thông minh"},
    "en": {"name": "Smart Plug"}
  }
}''';

      final meta = ProfileMetadata.tryParse(description);

      expect(meta.v, 1);
      expect(meta.uiType, 'smart_plug');
      expect(meta.icon, 'power');
      expect(meta.colorPrimary, '#4CAF50');
      expect(meta.isEmpty, isFalse);

      // states
      expect(meta.states.length, 3);
      final onoff = meta.states['onoff0']!;
      expect(onoff.type, 'bool');
      expect(onoff.controllable, isTrue);
      expect(onoff.labelDefault, 'Bật/Tắt');

      final power = meta.states['power']!;
      expect(power.type, 'number');
      expect(power.unit, 'W');
      expect(power.range?.min, 0);
      expect(power.range?.max, 3000);
      expect(power.chartable, isTrue);
      expect(power.precision, 1);

      final energy = meta.states['energy']!;
      expect(energy.cumulative, isTrue);
      expect(energy.unit, 'kWh');

      // actions
      expect(meta.actions.length, 2);
      expect(meta.actions['setValue']!.paramsHint, ['onoff0']);
      expect(meta.actions['toggle']!.paramsHint, isEmpty);

      // ui_hints
      expect(meta.uiHints?.primaryState, 'onoff0');
      expect(meta.uiHints?.summaryStates, ['power', 'energy']);
      expect(meta.uiHints?.cardLayout, 'toggle_with_metrics');
      expect(meta.uiHints?.maxPower, 3000.0);
      expect(meta.uiHints?.chartKeys, ['power', 'energy']);
      expect(meta.uiHints?.quickActions.length, 1);
      expect(meta.uiHints?.quickActions.first.method, 'toggle');

      // automation
      expect(meta.automation?.conditions.length, 2);
      expect(meta.automation?.conditions.first.key, 'onoff0');
      expect(meta.automation?.conditions.first.ops, ['==', '!=']);
      expect(meta.automation?.actions.length, 2);
      expect(meta.automation?.actions.first.param, 'onoff0');
      expect(meta.automation?.actions.last.param, isNull);

      // i18n
      expect(meta.localizedName('vi'), 'Ổ cắm thông minh');
      expect(meta.localizedName('en'), 'Smart Plug');
    });

    test('parses minimal description (chỉ có ui_type)', () {
      final meta = ProfileMetadata.tryParse('{"ui_type": "light"}');
      expect(meta.uiType, 'light');
      expect(meta.states, isEmpty);
      expect(meta.actions, isEmpty);
      expect(meta.uiHints, isNull);
      expect(meta.automation, isNull);
    });

    // ── missing / null ─────────────────────────────────────────────────────

    test('returns empty ProfileMetadata for null description', () {
      final meta = ProfileMetadata.tryParse(null);
      expect(meta.isEmpty, isTrue);
      expect(meta.uiType, 'auto');
      expect(meta.v, 1);
    });

    test('returns empty ProfileMetadata for empty string', () {
      final meta = ProfileMetadata.tryParse('');
      expect(meta.isEmpty, isTrue);
    });

    // ── corrupted ──────────────────────────────────────────────────────────

    test('returns empty ProfileMetadata for invalid JSON', () {
      final meta = ProfileMetadata.tryParse('not json at all {{{');
      expect(meta.isEmpty, isTrue);
    });

    test('returns empty ProfileMetadata for JSON array (not object)', () {
      final meta = ProfileMetadata.tryParse('[1, 2, 3]');
      expect(meta.isEmpty, isTrue);
    });

    test('returns empty ProfileMetadata for plain string (legacy image URL)', () {
      // Trước khi patch backend, description có thể là URL ảnh
      final meta = ProfileMetadata.tryParse(
        'tb-image;/api/images/tenant/ui_light.png',
      );
      expect(meta.isEmpty, isTrue);
    });

    // ── future-version ─────────────────────────────────────────────────────

    test('tolerates unknown fields from future schema version', () {
      final json = jsonEncode({
        'v': 99,
        'ui_type': 'smart_plug',
        'future_field': 'some_value',
        'states': {
          'onoff0': {
            'type': 'bool',
            'controllable': true,
            'future_state_field': true,
          },
        },
      });
      final meta = ProfileMetadata.tryParse(json);
      // Phải parse được — không throw
      expect(meta.v, 99);
      expect(meta.uiType, 'smart_plug');
      expect(meta.states['onoff0']?.type, 'bool');
      expect(meta.states['onoff0']?.controllable, isTrue);
    });

    test('tolerates missing optional state fields', () {
      final json = jsonEncode({
        'v': 1,
        'states': {
          'temp': {'type': 'number'},
        },
      });
      final meta = ProfileMetadata.tryParse(json);
      final temp = meta.states['temp']!;
      expect(temp.type, 'number');
      expect(temp.unit, isNull);
      expect(temp.controllable, isFalse);
      expect(temp.chartable, isFalse);
      expect(temp.range, isNull);
    });
  });
}
