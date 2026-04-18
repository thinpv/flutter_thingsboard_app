import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';

/// mPipe-style login background — clean warm off-white, no painted shapes.
class LoginPageBackground extends StatelessWidget {
  const LoginPageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: MpColors.bg, child: SizedBox.expand());
  }
}
