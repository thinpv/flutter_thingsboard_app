import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/widgets/mpipe_logo.dart';

/// mPipe login header: target logo icon + "mPipe" wordmark.
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MpipeLogo(size: 42),
        SizedBox(width: 12),
        Text(
          'mPipe',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
            color: MpColors.text,
          ),
        ),
      ],
    );
  }
}
