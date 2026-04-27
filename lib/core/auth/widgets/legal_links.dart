import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/constants/app_constants.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Helpers + reusable widgets for linking to the public Privacy Policy +
/// Terms of Service pages hosted alongside the API endpoint
/// ([ThingsboardAppConstants.thingsBoardApiEndpoint]/privacy and /terms).
///
/// Centralised here so signup, login, and any future entry point share the
/// same URL builders + visual style — Google Smart Home certification
/// requires both to be reachable from the consumer-facing surface.
class LegalLinks {
  const LegalLinks._();

  static String get privacyUrl =>
      '${ThingsboardAppConstants.thingsBoardApiEndpoint}/privacy';
  static String get termsUrl =>
      '${ThingsboardAppConstants.thingsBoardApiEndpoint}/terms';

  static Future<void> openPrivacy() => _open(privacyUrl);
  static Future<void> openTerms() => _open(termsUrl);

  static Future<void> _open(String url) async {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

/// Inline TextSpans for RichText — used in the signup consent checkbox so the
/// underlined phrases "Điều khoản dịch vụ" / "Chính sách riêng tư" actually
/// open the corresponding page when tapped (previously they were styled but
/// inert).
///
/// Each call constructs a new GestureRecognizer; do not memoise the returned
/// span across rebuilds.
class LegalTextSpans {
  const LegalTextSpans._();

  static TextSpan terms({String text = 'Điều khoản dịch vụ', Color? color}) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color ?? MpColors.text,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()..onTap = LegalLinks.openTerms,
    );
  }

  static TextSpan privacy({String text = 'Chính sách riêng tư', Color? color}) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color ?? MpColors.text,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()..onTap = LegalLinks.openPrivacy,
    );
  }
}

/// Compact "Chính sách bảo mật · Điều khoản" row for the bottom of the
/// login screen. Sits in the existing footer slot the CE/PE login layouts
/// already render.
class LegalLinksFooter extends StatelessWidget {
  const LegalLinksFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LinkButton(
            label: 'Chính sách bảo mật',
            onTap: LegalLinks.openPrivacy,
          ),
          const Text(
            ' · ',
            style: TextStyle(fontSize: 12, color: MpColors.text3),
          ),
          _LinkButton(label: 'Điều khoản', onTap: LegalLinks.openTerms),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: MpColors.text3,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
