// C-A-12: Regression test — automation rule với 5 device type khác nhau.
// Verify: build → toJson → fromJson round-trip, executionTarget, schedule,
// conditionMatch, enabled flag, và tap-to-run (0 conditions).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thingsboard_app/modules/smarthome/smart/domain/entities/automation_rule.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

AutomationRule _roundTrip(AutomationRule rule) {
  final json = rule.toJson();
  // Simulate JSON encode/decode (as stored in TB server_attr or shared_attr)
  final encoded = jsonEncode(json);
  final decoded = jsonDecode(encoded) as Map<String, dynamic>;
  return AutomationRule.fromJson(decoded);
}

void _expectRoundTrip(AutomationRule rule) {
  final rt = _roundTrip(rule);
  expect(rt.id, rule.id, reason: 'id');
  expect(rt.name, rule.name, reason: 'name');
  expect(rt.enabled, rule.enabled, reason: 'enabled');
  expect(rt.executionTarget, rule.executionTarget, reason: 'executionTarget');
  expect(rt.conditionMatch, rule.conditionMatch, reason: 'conditionMatch');
  expect(rt.conditions.length, rule.conditions.length, reason: 'conditions.length');
  expect(rt.actions.length, rule.actions.length, reason: 'actions.length');
}

// ─── 5 device-type rules ─────────────────────────────────────────────────────

/// Device type 1: Light — Bật/tắt đèn khi motion cảm biến ON, thực thi trên gateway
AutomationRule _lightRule() => AutomationRule(
      id: 'rule-light-001',
      name: 'Bật đèn phòng khách khi có người',
      icon: 'lightbulb',
      color: '#FFC107',
      enabled: true,
      executionTarget: 'gw:gw-home-001',
      conditionMatch: ConditionMatch.any,
      conditions: [
        RuleCondition(raw: {
          'type': 'device',
          'deviceId': 'motion-sensor-001',
          'key': 'pir',
          'op': '==',
          'value': 1,
        }),
      ],
      actions: [
        RuleAction(raw: {
          'type': 'device',
          'deviceId': 'light-001',
          'data': {'onoff0': 1, 'dim': 80},
        }),
      ],
    );

/// Device type 2: Smart plug — Tắt ổ cắm khi công suất vượt ngưỡng, server rule
AutomationRule _smartPlugRule() => AutomationRule(
      id: 'rule-plug-001',
      name: 'Tắt ổ cắm quá tải',
      icon: 'electrical_services',
      color: '#F44336',
      enabled: true,
      executionTarget: 'server',
      conditionMatch: ConditionMatch.all,
      conditions: [
        RuleCondition(raw: {
          'type': 'device',
          'deviceId': 'smart-plug-001',
          'key': 'power',
          'op': '>',
          'value': 2500,
        }),
      ],
      actions: [
        RuleAction(raw: {
          'type': 'device',
          'deviceId': 'smart-plug-001',
          'data': {'onoff0': 0},
        }),
        RuleAction(raw: {
          'type': 'notify',
          'message': 'Ổ cắm phòng bếp quá tải!',
          'target': 'all',
        }),
      ],
    );

/// Device type 3: Temp-humidity sensor — Bật điều hòa khi nhiệt độ cao, ALL conditions
AutomationRule _tempHumRule() => AutomationRule(
      id: 'rule-temphum-001',
      name: 'Tự động bật điều hòa',
      icon: 'thermostat',
      color: '#03A9F4',
      enabled: true,
      executionTarget: 'gw:gw-home-001',
      conditionMatch: ConditionMatch.all,
      schedule: RuleSchedule(
        days: 62, // T2–T6
        timeFrom: '08:00',
        timeTo: '22:00',
      ),
      conditions: [
        RuleCondition(raw: {
          'type': 'device',
          'deviceId': 'sensor-temphum-001',
          'key': 'temp',
          'op': '>',
          'value': 29,
        }),
        RuleCondition(raw: {
          'type': 'device',
          'deviceId': 'sensor-temphum-001',
          'key': 'hum',
          'op': '>',
          'value': 70,
        }),
      ],
      actions: [
        RuleAction(raw: {
          'type': 'device',
          'deviceId': 'ac-001',
          'data': {'onoff0': 1, 'coolSp': 25},
        }),
      ],
    );

/// Device type 4: Air conditioner — Tắt điều hòa theo giờ, timer condition
AutomationRule _acRule() => AutomationRule(
      id: 'rule-ac-001',
      name: 'Tắt điều hòa lúc 23:00',
      icon: 'ac_unit',
      color: '#9C27B0',
      enabled: true,
      executionTarget: 'gw:gw-home-001',
      conditionMatch: ConditionMatch.all,
      schedule: RuleSchedule(days: 127), // every day
      conditions: [
        RuleCondition(raw: {
          'type': 'timer',
          'days': 127,
          'time': '23:00',
        }),
      ],
      actions: [
        RuleAction(raw: {
          'type': 'device',
          'deviceId': 'ac-001',
          'data': {'onoff0': 0},
        }),
      ],
    );

/// Device type 5: Curtain — Kịch bản "buổi sáng" tap-to-run (0 conditions),
/// multiple devices, server rule
AutomationRule _curtainRule() => AutomationRule(
      id: 'rule-curtain-001',
      name: 'Buổi sáng: mở rèm + đèn nhẹ',
      icon: 'wb_sunny',
      color: '#FF9800',
      enabled: true,
      executionTarget: 'server',
      conditionMatch: ConditionMatch.all,
      conditions: [], // tap-to-run
      actions: [
        RuleAction(raw: {
          'type': 'device',
          'deviceId': 'curtain-001',
          'data': {'pos': 80},
        }),
        RuleAction(raw: {
          'type': 'delay',
          'seconds': 5,
        }),
        RuleAction(raw: {
          'type': 'device',
          'deviceId': 'light-001',
          'data': {'onoff0': 1, 'dim': 30, 'ct': 300},
        }),
      ],
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('AutomationRule — round-trip serialization (5 device types)', () {
    test('Light rule: pir → onoff0+dim, gw target, ANY match', () {
      final rule = _lightRule();
      _expectRoundTrip(rule);
      final rt = _roundTrip(rule);
      expect(rt.isGatewayRule, isTrue);
      expect(rt.gatewayId, 'gw-home-001');
      expect(rt.conditionMatch, ConditionMatch.any);
      expect(rt.conditions.first.raw['key'], 'pir');
      expect(rt.actions.first.raw['data']['dim'], 80);
    });

    test('Smart plug rule: power threshold → toggle OFF + notify, server', () {
      final rule = _smartPlugRule();
      _expectRoundTrip(rule);
      final rt = _roundTrip(rule);
      expect(rt.isGatewayRule, isFalse);
      expect(rt.executionTarget, 'server');
      expect(rt.conditionMatch, ConditionMatch.all);
      expect(rt.conditions.first.raw['value'], 2500);
      expect(rt.actions.first.raw['data']['onoff0'], 0);
      expect(rt.actions[1].type, 'notify');
    });

    test('Temp-hum rule: temp+hum ALL conditions, with schedule T2-T6', () {
      final rule = _tempHumRule();
      _expectRoundTrip(rule);
      final rt = _roundTrip(rule);
      expect(rt.conditions.length, 2);
      expect(rt.conditionMatch, ConditionMatch.all);
      expect(rt.schedule, isNotNull);
      expect(rt.schedule!.days, 62);
      expect(rt.schedule!.timeFrom, '08:00');
      expect(rt.schedule!.timeTo, '22:00');
      expect(rt.actions.first.raw['data']['coolSp'], 25);
    });

    test('AC rule: timer condition every day, no time window', () {
      final rule = _acRule();
      _expectRoundTrip(rule);
      final rt = _roundTrip(rule);
      expect(rt.conditions.first.type, 'timer');
      expect(rt.conditions.first.raw['time'], '23:00');
      expect(rt.schedule!.days, 127);
      expect(rt.schedule!.timeFrom, isNull);
    });

    test('Curtain rule: tap-to-run (0 conditions), delay action, server', () {
      final rule = _curtainRule();
      _expectRoundTrip(rule);
      final rt = _roundTrip(rule);
      expect(rt.conditions, isEmpty);
      expect(rt.actions.length, 3);
      expect(rt.actions[1].type, 'delay');
      expect(rt.actions[1].raw['seconds'], 5);
      expect(rt.actions[2].raw['data']['ct'], 300);
    });
  });

  group('AutomationRule — enabled flag', () {
    test('disabled rule survives round-trip', () {
      final rule = _lightRule().copyWith(enabled: false);
      expect(rule.enabled, isFalse);
      final rt = _roundTrip(rule);
      expect(rt.enabled, isFalse);
    });

    test('re-enabling a disabled rule works', () {
      final disabled = _lightRule().copyWith(enabled: false);
      final enabled = disabled.copyWith(enabled: true);
      expect(enabled.enabled, isTrue);
    });
  });

  group('AutomationRule — executionTarget', () {
    test('isGatewayRule true for gw: prefix', () {
      expect(_lightRule().isGatewayRule, isTrue);
      expect(_lightRule().gatewayId, 'gw-home-001');
    });

    test('isGatewayRule false for server', () {
      expect(_smartPlugRule().isGatewayRule, isFalse);
      expect(_smartPlugRule().gatewayId, isNull);
    });

    test('executionTarget preserved exactly in toJson', () {
      final json = _lightRule().toJson();
      expect(json['executionTarget'], 'gw:gw-home-001');
    });
  });

  group('AutomationRule — conditionMatch serialization', () {
    test('ConditionMatch.all → "all" in JSON', () {
      final json = _smartPlugRule().toJson();
      expect(json['conditionMatch'], 'all');
    });

    test('ConditionMatch.any → "any" in JSON', () {
      final json = _lightRule().toJson();
      expect(json['conditionMatch'], 'any');
    });

    test('"any" string → ConditionMatch.any on fromJson', () {
      final rt = _roundTrip(_lightRule());
      expect(rt.conditionMatch, ConditionMatch.any);
    });
  });

  group('AutomationRule — JSON format compliance (unified schema)', () {
    test('all top-level keys present for light rule', () {
      final json = _lightRule().toJson();
      for (final key in ['id', 'name', 'icon', 'color', 'enabled',
          'ts', 'executionTarget', 'conditionMatch',
          'conditions', 'actions']) {
        expect(json.containsKey(key), isTrue, reason: 'missing key: $key');
      }
    });

    test('device condition has required keys', () {
      final cond = _lightRule().conditions.first.toJson();
      expect(cond['type'], 'device');
      expect(cond.containsKey('deviceId'), isTrue);
      expect(cond.containsKey('key'), isTrue);
      expect(cond.containsKey('op'), isTrue);
      expect(cond.containsKey('value'), isTrue);
    });

    test('device action data is a Map', () {
      final action = _lightRule().actions.first.toJson();
      expect(action['type'], 'device');
      expect(action['data'], isA<Map>());
    });

    test('delay action has seconds key', () {
      final action = _curtainRule().actions[1].toJson();
      expect(action['type'], 'delay');
      expect(action['seconds'], isA<int>());
    });

    test('schedule uses timeFrom/timeTo keys (not time_from/time_to)', () {
      final json = _tempHumRule().toJson();
      final schedule = json['schedule'] as Map;
      expect(schedule.containsKey('timeFrom'), isTrue);
      expect(schedule.containsKey('timeTo'), isTrue);
      expect(schedule.containsKey('time_from'), isFalse);
    });
  });

  group('AutomationRule — RuleIndexEntry', () {
    test('fromRule preserves id/name/icon/color/enabled', () {
      final rule = _lightRule();
      final entry = RuleIndexEntry.fromRule(rule);
      expect(entry.id, rule.id);
      expect(entry.name, rule.name);
      expect(entry.icon, rule.icon);
      expect(entry.color, rule.color);
      expect(entry.enabled, rule.enabled);
    });

    test('fromRule toJson has required gateway index fields', () {
      final entry = RuleIndexEntry.fromRule(_lightRule());
      final json = entry.toJson();
      for (final key in ['id', 'name', 'icon', 'color', 'enabled', 'ts', 'status']) {
        expect(json.containsKey(key), isTrue, reason: 'missing field: $key');
      }
    });

    test('RuleIndexEntry round-trip', () {
      final entry = RuleIndexEntry.fromRule(_lightRule());
      final rt = RuleIndexEntry.fromJson(entry.toJson());
      expect(rt.id, entry.id);
      expect(rt.enabled, entry.enabled);
      expect(rt.ts, entry.ts);
    });
  });
}
