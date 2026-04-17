// A-A-10: Unit test serialization round-trip cho tất cả models
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/action_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/automation_caps.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/profile_metadata.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/state_def.dart';
import 'package:thingsboard_app/modules/smarthome/profile_metadata/domain/ui_hints.dart';

void main() {
  group('StateDef round-trip', () {
    test('bool controllable', () {
      const original = StateDef(
        type: 'bool',
        controllable: true,
        labelDefault: 'Bật/Tắt',
        labelKey: 'state.onoff0',
        icon: 'toggle_on',
      );
      final json = original.toJson();
      final restored = StateDef.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.controllable, original.controllable);
      expect(restored.labelDefault, original.labelDefault);
      expect(restored.labelKey, original.labelKey);
      expect(restored.icon, original.icon);
      expect(restored.cumulative, isFalse);
      expect(restored.chartable, isFalse);
    });

    test('number with range and precision', () {
      const original = StateDef(
        type: 'number',
        unit: 'W',
        range: StateRange(min: 0, max: 3000),
        precision: 1,
        chartable: true,
        cumulative: false,
      );
      final json = original.toJson();
      final restored = StateDef.fromJson(json);

      expect(restored.unit, 'W');
      expect(restored.range?.min, 0.0);
      expect(restored.range?.max, 3000.0);
      expect(restored.precision, 1);
      expect(restored.chartable, isTrue);
    });

    test('enum with enumValues', () {
      const original = StateDef(
        type: 'enum',
        enumValues: ['off', 'heat', 'cool', 'auto'],
        controllable: true,
      );
      final json = original.toJson();
      final restored = StateDef.fromJson(json);

      expect(restored.type, 'enum');
      expect(restored.enumValues, ['off', 'heat', 'cool', 'auto']);
    });
  });

  group('ActionMetaDef round-trip', () {
    test('setValue with params', () {
      const original = ActionMetaDef(paramsHint: ['onoff0']);
      final restored = ActionMetaDef.fromJson(original.toJson());
      expect(restored.paramsHint, ['onoff0']);
    });

    test('toggle no params', () {
      const original = ActionMetaDef(paramsHint: []);
      final restored = ActionMetaDef.fromJson(original.toJson());
      expect(restored.paramsHint, isEmpty);
    });
  });

  group('UiHints round-trip', () {
    test('full hints', () {
      const original = UiHints(
        primaryState: 'onoff0',
        summaryStates: ['power', 'energy'],
        cardLayout: 'toggle_with_metrics',
        detailLayout: 'auto',
        maxPower: 3000.0,
        chartKeys: ['power', 'energy'],
        quickActions: [
          QuickAction(
            method: 'toggle',
            label: 'Bật/Tắt',
            icon: 'power_settings_new',
          ),
        ],
      );
      final json = original.toJson();
      final restored = UiHints.fromJson(json);

      expect(restored.primaryState, 'onoff0');
      expect(restored.summaryStates, ['power', 'energy']);
      expect(restored.cardLayout, 'toggle_with_metrics');
      expect(restored.maxPower, 3000.0);
      expect(restored.chartKeys, ['power', 'energy']);
      expect(restored.quickActions.length, 1);
      expect(restored.quickActions.first.method, 'toggle');
      expect(restored.quickActions.first.icon, 'power_settings_new');
    });

    test('defaults when fields absent', () {
      final restored = UiHints.fromJson({});
      expect(restored.primaryState, isNull);
      expect(restored.summaryStates, isEmpty);
      expect(restored.cardLayout, 'auto');
      expect(restored.detailLayout, 'auto');
      expect(restored.maxPower, isNull);
      expect(restored.chartKeys, isEmpty);
      expect(restored.quickActions, isEmpty);
    });
  });

  group('AutomationCaps round-trip', () {
    test('conditions and actions', () {
      const original = AutomationCaps(
        conditions: [
          ConditionCap(key: 'onoff0', ops: ['==', '!=']),
          ConditionCap(key: 'power', ops: ['>', '<', '<>']),
        ],
        actions: [
          ActionCap(method: 'setValue', param: 'onoff0'),
          ActionCap(method: 'toggle'),
        ],
      );
      final json = original.toJson();
      final restored = AutomationCaps.fromJson(json);

      expect(restored.conditions.length, 2);
      expect(restored.conditions[0].key, 'onoff0');
      expect(restored.conditions[0].ops, ['==', '!=']);
      expect(restored.conditions[1].ops, ['>', '<', '<>']);

      expect(restored.actions.length, 2);
      expect(restored.actions[0].method, 'setValue');
      expect(restored.actions[0].param, 'onoff0');
      expect(restored.actions[1].method, 'toggle');
      expect(restored.actions[1].param, isNull);
    });
  });

  group('ProfileMetadata round-trip', () {
    test('full metadata', () {
      const original = ProfileMetadata(
        v: 1,
        uiType: 'smartPlug',
        icon: 'power',
        colorPrimary: '#4CAF50',
        states: {
          'onoff0': StateDef(type: 'bool', controllable: true),
          'power': StateDef(
            type: 'number',
            unit: 'W',
            range: StateRange(min: 0, max: 3000),
            chartable: true,
          ),
        },
        actions: {
          'toggle': ActionMetaDef(paramsHint: []),
        },
        uiHints: UiHints(primaryState: 'onoff0', summaryStates: ['power']),
        automation: AutomationCaps(
          conditions: [ConditionCap(key: 'onoff0', ops: ['=='])],
          actions: [ActionCap(method: 'toggle')],
        ),
        i18n: {
          'vi': {'name': 'Ổ cắm thông minh'},
          'en': {'name': 'Smart Plug'},
        },
      );

      final jsonStr = jsonEncode(original.toJson());
      final restored = ProfileMetadata.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );

      expect(restored.v, 1);
      expect(restored.uiType, 'smartPlug');
      expect(restored.icon, 'power');
      expect(restored.colorPrimary, '#4CAF50');
      expect(restored.isEmpty, isFalse);

      expect(restored.states['onoff0']?.controllable, isTrue);
      expect(restored.states['power']?.range?.max, 3000.0);
      expect(restored.states['power']?.chartable, isTrue);

      expect(restored.actions['toggle']?.paramsHint, isEmpty);
      expect(restored.uiHints?.primaryState, 'onoff0');
      expect(restored.automation?.conditions.first.key, 'onoff0');
      expect(restored.localizedName('vi'), 'Ổ cắm thông minh');
      expect(restored.localizedName('en'), 'Smart Plug');
    });

    test('empty ProfileMetadata round-trips without error', () {
      const original = ProfileMetadata();
      final jsonStr = jsonEncode(original.toJson());
      final restored = ProfileMetadata.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      expect(restored.isEmpty, isTrue);
      expect(restored.v, 1);
      expect(restored.uiType, 'auto');
    });
  });
}
