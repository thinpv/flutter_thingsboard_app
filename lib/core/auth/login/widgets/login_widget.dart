import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/core/auth/login/provider/oauth_provider.dart';
import 'package:thingsboard_app/core/auth/login/widgets/footer/login_footer.dart';
import 'package:thingsboard_app/core/auth/login/widgets/full_screen_loader.dart';
import 'package:thingsboard_app/core/auth/login/widgets/header/login_header.dart';
import 'package:thingsboard_app/core/auth/login/widgets/o_auth_buttons.dart';
import 'package:thingsboard_app/generated/l10n.dart';
import 'package:thingsboard_app/thingsboard_client.dart';
import 'package:thingsboard_app/utils/ui/visibility_widget.dart';

class LoginWidget extends HookConsumerWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = useState(true);
    final providers = ref.watch(oauthProvider);
    final showPassword = useState(false);

    final form = useMemoized(
      () => FormGroup({
        'email': FormControl<String>(
          value: 'user@smarthome.io',
          validators: [Validators.required, Validators.email],
        ),
        'password': FormControl<String>(
          value: 'smarthome123',
          validators: [Validators.required],
        ),
      }),
    );

    useEffect(() {
      if (providers is! AsyncLoading) loading.value = false;
      return null;
    }, [providers]);

    final oauthClients = (providers.value?.oAuth2Clients ?? [])
        .where((c) => c.name != 'qr')
        .toList();
    final hasOAuth = oauthClients.isNotEmpty;

    return Stack(
      children: [
        // ── mPipe input theme override ─────────────────────────────────
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
                borderSide: const BorderSide(color: MpColors.border, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MpColors.border, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MpColors.text, width: 1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MpColors.red, width: 0.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MpColors.red, width: 1),
              ),
              labelStyle: const TextStyle(
                color: MpColors.text3,
                fontSize: 15,
              ),
              hintStyle: const TextStyle(
                color: MpColors.text3,
                fontSize: 15,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              isDense: true,
            ),
          ),
          child: ReactiveForm(
            formGroup: form,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        32,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo ──────────────────────────────────────────
                        const SizedBox(height: 24),
                        const Center(child: LoginHeader()),
                        const SizedBox(height: 40),

                        // ── Tagline ───────────────────────────────────────
                        const Text(
                          'Chào mừng trở lại',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                            color: MpColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Nhập thông tin tài khoản mPipe của bạn',
                          style: TextStyle(
                            fontSize: 13,
                            color: MpColors.text3,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Email field ───────────────────────────────────
                        ReactiveTextField<String>(
                          formControlName: 'email',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          style: const TextStyle(
                            fontSize: 15,
                            color: MpColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Email hoặc số điện thoại',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(14),
                              child: _MailIcon(),
                            ),
                          ),
                          validationMessages: {
                            ValidationMessage.required: (_) =>
                                'Email không được để trống',
                            ValidationMessage.email: (_) =>
                                'Email không hợp lệ',
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Password field ────────────────────────────────
                        ReactiveTextField<String>(
                          formControlName: 'password',
                          obscureText: !showPassword.value,
                          autofillHints: const [AutofillHints.password],
                          style: const TextStyle(
                            fontSize: 15,
                            color: MpColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Mật khẩu',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(14),
                              child: _LockIcon(),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () =>
                                  showPassword.value = !showPassword.value,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: _EyeIcon(open: showPassword.value),
                              ),
                            ),
                          ),
                          validationMessages: {
                            ValidationMessage.required: (_) =>
                                'Mật khẩu không được để trống',
                          },
                        ),

                        // ── Forgot password ───────────────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => onForgotPassword(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                fontSize: 13,
                                color: MpColors.blue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Login button ──────────────────────────────────
                        ReactiveFormConsumer(
                          builder: (context, formGroup, _) {
                            final enabled =
                                !(formGroup.invalid && formGroup.touched);
                            return _MpButton(
                              label: S.of(context).login,
                              enabled: enabled,
                              onTap: () => onLoginPressed(
                                context,
                                form,
                                ref,
                                loading,
                              ),
                            );
                          },
                        ),

                        // ── Sign-up link ──────────────────────────────────
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Chưa có tài khoản?',
                              style: TextStyle(
                                fontSize: 13,
                                color: MpColors.text3,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/login/signup'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Đăng ký',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: MpColors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── OAuth divider + buttons ───────────────────────
                        if (hasOAuth) ...[
                          const SizedBox(height: 28),
                          _MpDivider(text: S.of(context).or),
                          const SizedBox(height: 20),
                          OAuthButtons(
                            onButtonPressed: (client) =>
                                onOauth2ButtonPressed(
                              client,
                              context,
                              loading,
                              ref,
                            ),
                            clients: oauthClients,
                          ),
                        ],

                        const Spacer(),
                        const LoginFooter(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        AnimatedVisibilityWidget(
          show: loading.value || providers is AsyncLoading,
          child: const FullScreenLoader(),
        ),
      ],
    );
  }
}

// ─── Helper SVG-style icons (CustomPaint, no package dependency) ──────────────

class _MailIcon extends StatelessWidget {
  const _MailIcon();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(18, 18),
        painter: _IconPainter(_mailPath),
      );
  static void _mailPath(Canvas c, Size s) {
    final p = _stroke(c, s);
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 3, 15, 12),
      const Radius.circular(1.5),
    );
    c.drawRRect(rr, p);
    final lp = Path()
      ..moveTo(2, 4)
      ..lineTo(9, 9.5)
      ..lineTo(16, 4);
    c.drawPath(lp, p);
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(18, 18),
        painter: _IconPainter(_lockPath),
      );
  static void _lockPath(Canvas c, Size s) {
    final p = _stroke(c, s);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 8, 12, 8),
      const Radius.circular(1.5),
    );
    c.drawRRect(body, p);
    final arc = Path()
      ..moveTo(6, 8)
      ..lineTo(6, 6)
      ..arcToPoint(const Offset(12, 6), radius: const Radius.circular(3))
      ..lineTo(12, 8);
    c.drawPath(arc, p);
  }
}

class _EyeIcon extends StatelessWidget {
  const _EyeIcon({required this.open});
  final bool open;
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(18, 18),
        painter: _IconPainter(open ? _eyeOpen : _eyeClosed),
      );
  static void _eyeOpen(Canvas c, Size s) {
    final p = _stroke(c, s);
    final eye = Path()
      ..moveTo(1, 9)
      ..cubicTo(4, 4, 14, 4, 17, 9)
      ..cubicTo(14, 14, 4, 14, 1, 9);
    c.drawPath(eye, p);
    c.drawCircle(const Offset(9, 9), 2.5, p);
  }

  static void _eyeClosed(Canvas c, Size s) {
    final p = _stroke(c, s);
    final eye = Path()
      ..moveTo(1, 9)
      ..cubicTo(4, 4, 14, 4, 17, 9)
      ..cubicTo(14, 14, 4, 14, 1, 9);
    c.drawPath(eye, p);
    final slash = Path()
      ..moveTo(2, 2)
      ..lineTo(16, 16);
    c.drawPath(slash, p);
  }
}

Paint _stroke(Canvas c, Size s) => Paint()
  ..color = MpColors.text3
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

class _IconPainter extends CustomPainter {
  const _IconPainter(this.fn);
  final void Function(Canvas, Size) fn;
  @override
  void paint(Canvas c, Size s) => fn(c, s);
  @override
  bool shouldRepaint(_IconPainter old) => false;
}

// ─── mPipe primary button ─────────────────────────────────────────────────────

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
          color: enabled ? MpColors.text : MpColors.text.withValues(alpha: 0.2),
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

// ─── mPipe divider ────────────────────────────────────────────────────────────

class _MpDivider extends StatelessWidget {
  const _MpDivider({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: MpColors.border, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: MpColors.text3),
          ),
        ),
        const Expanded(child: Divider(color: MpColors.border, thickness: 0.5)),
      ],
    );
  }
}

// ─── Handlers (unchanged logic) ───────────────────────────────────────────────

Future<void> onLoginPressed(
  BuildContext context,
  FormGroup form,
  WidgetRef ref,
  ValueNotifier<bool> loading,
) async {
  FocusScope.of(context).unfocus();
  form.markAllAsTouched();
  if (form.invalid) return;
  final username = form.control('email').value.toString();
  final password = form.control('password').value.toString();
  try {
    loading.value = true;
    final res = await ref.read(loginProvider.notifier).login(username, password);
    loading.value = res;
  } catch (e) {
    form.setErrors({'err': {}});
  }
}

Future<void> onOauth2ButtonPressed(
  OAuth2ClientInfo client,
  BuildContext context,
  ValueNotifier<bool> loading,
  WidgetRef ref,
) async {
  FocusScope.of(context).unfocus();
  loading.value = true;
  final res = await ref.read(loginProvider.notifier).oauthLogin(client.url);
  loading.value = res;
}

Future<void> onForgotPassword(BuildContext context) async {
  context.push('/login/resetPasswordRequest');
}
