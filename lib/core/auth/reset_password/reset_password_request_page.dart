import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/core/auth/login/widgets/full_screen_loader.dart';
import 'package:thingsboard_app/core/logger/tb_logger.dart';
import 'package:thingsboard_app/generated/l10n.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/utils/services/overlay_service/i_overlay_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';
import 'package:thingsboard_app/utils/ui/visibility_widget.dart';

class ResetPasswordRequestPage extends HookConsumerWidget {
  const ResetPasswordRequestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = useMemoized(
      () => FormGroup({
        'email': FormControl<String>(
          validators: [Validators.required, Validators.email],
        ),
      }),
    );
    final isLoading = useState(false);

    return Scaffold(
      backgroundColor: MpColors.bg,
      body: Stack(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: MpColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: MpColors.border, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: MpColors.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: MpColors.text, width: 1),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: MpColors.red, width: 0.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MpColors.red, width: 1),
                ),
                labelStyle:
                    const TextStyle(color: MpColors.text3, fontSize: 15),
                hintStyle:
                    const TextStyle(color: MpColors.text3, fontSize: 15),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                isDense: true,
              ),
            ),
            child: SafeArea(
              child: ReactiveForm(
                formGroup: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header bar ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const _BackIcon(),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'Đặt lại mật khẩu',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: MpColors.text,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),

                    // ── Body ────────────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 32),

                            // ── Envelope illustration ─────────────────
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: MpColors.blueSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: _MailIcon(color: MpColors.blue),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Title + description ───────────────────
                            const Text(
                              'Quên mật khẩu?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                                color: MpColors.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nhập email tài khoản của bạn. Chúng tôi sẽ gửi liên kết để đặt lại mật khẩu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: MpColors.text3,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Email field ───────────────────────────
                            ReactiveTextField<String>(
                              formControlName: 'email',
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              style: const TextStyle(
                                  fontSize: 15, color: MpColors.text),
                              decoration: const InputDecoration(
                                hintText: 'Email',
                                prefixIcon: Padding(
                                  padding: EdgeInsets.all(14),
                                  child: _MailIcon(color: MpColors.text3),
                                ),
                              ),
                              validationMessages: {
                                ValidationMessage.required: (_) =>
                                    'Email không được để trống',
                                ValidationMessage.email: (_) =>
                                    'Email không hợp lệ',
                              },
                            ),

                            // ── Spacer pushes button to bottom ────────
                            const Spacer(),

                            // ── Submit button ─────────────────────────
                            ReactiveFormConsumer(
                              builder: (context, formGroup, _) {
                                final enabled =
                                    !(formGroup.invalid && formGroup.touched) &&
                                        !isLoading.value;
                                return _MpButton(
                                  label: S.of(context).requestPasswordReset,
                                  enabled: enabled,
                                  onTap: () => _requestPasswordReset(
                                      context, form, ref, isLoading),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedVisibilityWidget(
            show: isLoading.value,
            child: const FullScreenLoader(),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPasswordReset(
    BuildContext context,
    FormGroup form,
    WidgetRef ref,
    ValueNotifier<bool> isLoading,
  ) async {
    FocusScope.of(context).unfocus();
    form.markAllAsTouched();
    if (form.invalid) return;
    isLoading.value = true;
    final email = form.control('email').value.toString().trim().toLowerCase();
    try {
      await getIt<ITbClientService>().client.sendResetPasswordLink(email);
      getIt<IOverlayService>().showSuccessNotification(
        (_) => S.of(context).emailVerificationSentText,
      );
    } catch (e) {
      getIt<TbLogger>().error(e);
      getIt<IOverlayService>().showErrorNotification(
        (_) => '${S.of(context).fatalError}: $e',
      );
    }
    isLoading.value = false;
  }
}

// ── Mail icon ─────────────────────────────────────────────────────────────────

class _MailIcon extends StatelessWidget {
  const _MailIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(22, 22),
        painter: _MailIconPainter(color: color),
      );
}

class _MailIconPainter extends CustomPainter {
  const _MailIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 3.5, s.width - 3, s.height - 7),
      const Radius.circular(2),
    );
    c.drawRRect(rr, p);
    c.drawPath(
      Path()
        ..moveTo(2.5, 5)
        ..lineTo(s.width / 2, s.height / 2 + 1)
        ..lineTo(s.width - 2.5, 5),
      p,
    );
  }

  @override
  bool shouldRepaint(_MailIconPainter old) => old.color != color;
}

// ── Back icon ─────────────────────────────────────────────────────────────────

class _BackIcon extends StatelessWidget {
  const _BackIcon();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(18, 18),
        painter: _BackIconPainter(),
      );
}

class _BackIconPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = MpColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(11.5, 3)
        ..lineTo(5.5, 9)
        ..lineTo(11.5, 15),
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── mPipe primary button ──────────────────────────────────────────────────────

class _MpButton extends StatelessWidget {
  const _MpButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        decoration: BoxDecoration(
          color:
              enabled ? MpColors.text : MpColors.text.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: MpColors.bg,
          ),
        ),
      ),
    );
  }
}
