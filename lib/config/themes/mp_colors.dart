import 'package:flutter/material.dart';

/// mPipe SmartHome design palette — warm minimal (from mPipe design system).
abstract final class MpColors {
  // ── Backgrounds ────────────────────────────────────────────
  static const Color bg = Color(0xFFFAFAF7); // warm off-white page bg
  static const Color surface = Color(0xFFFFFFFF); // card / input surface
  static const Color surfaceAlt = Color(0xFFF0EFEA); // subtle alt surface

  // ── Text ───────────────────────────────────────────────────
  static const Color text = Color(0xFF1C1C1A); // primary near-black
  static const Color text2 = Color(0xFF5F5E5A); // secondary
  static const Color text3 = Color(0xFF888780); // muted / placeholder

  // ── Borders ────────────────────────────────────────────────
  static const Color border = Color(0x14000000); // rgba(0,0,0,0.08)
  static const Color borderStrong = Color(0x29000000); // rgba(0,0,0,0.16)

  // ── Accent: Blue ───────────────────────────────────────────
  static const Color blue = Color(0xFF185FA5);
  static const Color blueSoft = Color(0xFFE6F1FB);

  // ── Accent: Green ──────────────────────────────────────────
  static const Color green = Color(0xFF0F6E56);
  static const Color greenSoft = Color(0xFFE1F5EE);

  // ── Accent: Violet ─────────────────────────────────────────
  static const Color violet = Color(0xFF3C3489);
  static const Color violetSoft = Color(0xFFEEEDFE);

  // ── Accent: Amber ──────────────────────────────────────────
  static const Color amber = Color(0xFFBA7517);
  static const Color amberSoft = Color(0xFFFAEEDA);

  // ── Accent: Red ────────────────────────────────────────────
  static const Color red = Color(0xFFA32D2D);
  static const Color redSoft = Color(0xFFFCEBEB);

  // ── Helpers ────────────────────────────────────────────────

  /// Resolves tint + foreground color pair for a device type.
  static ({Color tint, Color fg}) deviceColors(String uiType, bool isOn) {
    if (!isOn) return (tint: surfaceAlt, fg: text3);
    return switch (uiType) {
      'light' || 'electricalSwitch' || 'switch' => (tint: amberSoft, fg: amber),
      'airConditioner' => (tint: blueSoft, fg: blue),
      'smartPlug' => (tint: greenSoft, fg: green),
      'curtain' || 'lock' => (tint: greenSoft, fg: green),
      'camera' => (tint: surfaceAlt, fg: text2),
      'doorSensor' || 'motionSensor' => (tint: violetSoft, fg: violet),
      'tempHumidity' || 'airQuality' => (tint: blueSoft, fg: blue),
      _ => (tint: surfaceAlt, fg: text2),
    };
  }
}
