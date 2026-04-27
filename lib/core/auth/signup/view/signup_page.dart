import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:thingsboard_app/config/themes/mp_colors.dart';
import 'package:thingsboard_app/core/auth/login/widgets/full_screen_loader.dart';
import 'package:thingsboard_app/core/auth/signup/provider/signup_provider.dart';
import 'package:thingsboard_app/core/auth/widgets/legal_links.dart';
import 'package:thingsboard_app/utils/ui/visibility_widget.dart';

class SignupPage extends HookConsumerWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = useMemoized(
      () => FormGroup({
        'name': FormControl<String>(validators: [Validators.required]),
        'email': FormControl<String>(
          validators: [Validators.required, Validators.email],
        ),
        'phone': FormControl<String>(),
        'password': FormControl<String>(
          validators: [Validators.required, Validators.minLength(8)],
        ),
      }),
    );

    final state = ref.watch(signupProvider);
    final showPassword = useState(false);
    final agreeTerms = useState(false);
    final agreeMarketing = useState(false);
    final focus = useState<String?>(null);
    final pwd = useState('');

    // track password value for strength UI
    useEffect(() {
      final ctrl = form.control('password') as FormControl<String>;
      ctrl.valueChanges.listen((_) => pwd.value = ctrl.value ?? '');
      return null;
    }, []);

    final hasLen = pwd.value.length >= 8;
    final hasCase = RegExp(r'[a-z]').hasMatch(pwd.value) &&
        RegExp(r'[A-Z]').hasMatch(pwd.value);
    final hasSpecial =
        RegExp(r'[0-9!@#$%^&*()\.,?":{}|<>]').hasMatch(pwd.value);
    final strength = [hasLen, hasCase, hasSpecial, pwd.value.length >= 12]
        .where((v) => v)
        .length;

    const strengthColors = [
      MpColors.text3,
      MpColors.red,
      MpColors.amber,
      MpColors.green,
      MpColors.green,
    ];
    const strengthLabels = ['', 'Yếu', 'Trung bình', 'Mạnh', 'Rất mạnh'];

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
                  borderSide: const BorderSide(color: MpColors.text, width: 1),
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
                hintStyle: const TextStyle(color: MpColors.text3, fontSize: 15),
                floatingLabelBehavior: FloatingLabelBehavior.never,
                isDense: true,
              ),
            ),
            child: ReactiveForm(
              formGroup: form,
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Header bar ────────────────────────────────────────
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
                                'Tạo tài khoản',
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

                    // ── Scrollable body ───────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Bắt đầu với mPipe',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                                color: MpColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Miễn phí cho 5 thiết bị đầu tiên',
                              style: TextStyle(
                                fontSize: 13,
                                color: MpColors.text3,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Họ và tên ─────────────────────────────────
                            ReactiveTextField<String>(
                              formControlName: 'name',
                              style: const TextStyle(
                                  fontSize: 15, color: MpColors.text),
                              decoration: const InputDecoration(
                                  hintText: 'Họ và tên'),
                              validationMessages: {
                                ValidationMessage.required: (_) =>
                                    'Vui lòng nhập họ và tên',
                              },
                            ),
                            const SizedBox(height: 10),

                            // ── Email ─────────────────────────────────────
                            ReactiveTextField<String>(
                              formControlName: 'email',
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              style: const TextStyle(
                                  fontSize: 15, color: MpColors.text),
                              decoration:
                                  const InputDecoration(hintText: 'Email'),
                              validationMessages: {
                                ValidationMessage.required: (_) =>
                                    'Email không được để trống',
                                ValidationMessage.email: (_) =>
                                    'Email không hợp lệ',
                              },
                            ),
                            const SizedBox(height: 10),

                            // ── Phone ─────────────────────────────────────
                            _PhoneField(
                              formControlName: 'phone',
                              isFocused: focus.value == 'phone',
                              onFocus: () => focus.value = 'phone',
                              onBlur: () => focus.value = null,
                            ),
                            const SizedBox(height: 10),

                            // ── Password ──────────────────────────────────
                            ReactiveTextField<String>(
                              formControlName: 'password',
                              obscureText: !showPassword.value,
                              autofillHints: const [AutofillHints.newPassword],
                              style: const TextStyle(
                                  fontSize: 15, color: MpColors.text),
                              decoration: InputDecoration(
                                hintText: 'Mật khẩu',
                                suffixIcon: GestureDetector(
                                  onTap: () => showPassword.value =
                                      !showPassword.value,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: _EyeIcon(open: showPassword.value),
                                  ),
                                ),
                              ),
                              validationMessages: {
                                ValidationMessage.required: (_) =>
                                    'Mật khẩu không được để trống',
                                ValidationMessage.minLength: (_) =>
                                    'Ít nhất 8 ký tự',
                                'hasCase': (_) =>
                                    'Cần có chữ hoa và chữ thường',
                                'hasSpecial': (_) =>
                                    'Cần có số hoặc ký tự đặc biệt',
                              },
                            ),

                            // ── Strength bar ──────────────────────────────
                            if (pwd.value.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: List.generate(4, (i) {
                                  return Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                          right: i < 3 ? 4 : 0),
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: i < strength
                                            ? strengthColors[strength]
                                            : MpColors.border,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  strengthLabels[strength],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: strength > 0
                                        ? strengthColors[strength]
                                        : MpColors.text3,
                                  ),
                                ),
                              ),
                            ],

                            // ── Password checklist ────────────────────────
                            const SizedBox(height: 12),
                            _PasswordCheck(ok: hasLen, label: 'Ít nhất 8 ký tự'),
                            const SizedBox(height: 6),
                            _PasswordCheck(
                                ok: hasCase, label: 'Có chữ hoa và thường'),
                            const SizedBox(height: 6),
                            _PasswordCheck(
                                ok: hasSpecial,
                                label: 'Có số hoặc ký tự đặc biệt'),

                            // ── Checkboxes ────────────────────────────────
                            const SizedBox(height: 20),
                            _ConsentCheckbox(
                              value: agreeTerms.value,
                              onChanged: (v) => agreeTerms.value = v,
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 12, color: MpColors.text2),
                                  children: [
                                    const TextSpan(text: 'Tôi đồng ý với '),
                                    LegalTextSpans.terms(),
                                    const TextSpan(text: ' và '),
                                    LegalTextSpans.privacy(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ConsentCheckbox(
                              value: agreeMarketing.value,
                              onChanged: (v) => agreeMarketing.value = v,
                              child: const Text(
                                'Nhận thông tin sản phẩm và ưu đãi qua email',
                                style: TextStyle(
                                    fontSize: 12, color: MpColors.text2),
                              ),
                            ),

                            // ── Error ─────────────────────────────────────
                            if (state.error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                state.error!,
                                style: const TextStyle(
                                    fontSize: 13, color: MpColors.red),
                              ),
                            ],

                            // ── Submit button ─────────────────────────────
                            const SizedBox(height: 20),
                            ReactiveFormConsumer(
                              builder: (context, formGroup, _) {
                                final valid = formGroup.valid &&
                                    agreeTerms.value &&
                                    !state.loading;
                                return _MpButton(
                                  label: 'Tạo tài khoản',
                                  enabled: valid,
                                  onTap: () =>
                                      _onSubmit(context, ref, form),
                                );
                              },
                            ),

                            // ── Login link ────────────────────────────────
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Đã có tài khoản?',
                                  style: TextStyle(
                                      fontSize: 13, color: MpColors.text3),
                                ),
                                TextButton(
                                  onPressed: () => context.pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 8),
                                  ),
                                  child: const Text(
                                    'Đăng nhập',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: MpColors.text,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
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
            show: state.loading,
            child: const FullScreenLoader(),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit(
      BuildContext context, WidgetRef ref, FormGroup form) async {
    FocusScope.of(context).unfocus();
    form.markAllAsTouched();
    if (form.invalid) return;
    final name = (form.control('name').value as String).trim();
    final email =
        (form.control('email').value as String).trim().toLowerCase();
    final password = form.control('password').value as String;
    try {
      await ref.read(signupProvider.notifier).register(
            email: email,
            password: password,
            firstName: name,
          );
      if (context.mounted) {
        context.push('/login/otpVerify', extra: email);
      }
    } catch (_) {
      // error already on state
    }
  }
}

// ── Phone field with +84 prefix ───────────────────────────────────────────────

class _PhoneField extends HookWidget {
  const _PhoneField({
    required this.formControlName,
    required this.isFocused,
    required this.onFocus,
    required this.onBlur,
  });

  final String formControlName;
  final bool isFocused;
  final VoidCallback onFocus;
  final VoidCallback onBlur;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 52,
      decoration: BoxDecoration(
        color: MpColors.surface,
        border: Border.all(
          color: isFocused ? MpColors.text : MpColors.border,
          width: isFocused ? 1.0 : 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text('🇻🇳', style: TextStyle(fontSize: 16)),
                SizedBox(width: 6),
                Text(
                  '+84',
                  style: TextStyle(
                    fontSize: 15,
                    color: MpColors.text,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(width: 6),
                _ChevronDown(),
              ],
            ),
          ),
          Container(width: 0.5, height: 28, color: MpColors.border),
          Expanded(
            child: ReactiveTextField<String>(
              formControlName: formControlName,
              keyboardType: TextInputType.phone,
              onChanged: (_) {},
              style: const TextStyle(fontSize: 15, color: MpColors.text),
              decoration: const InputDecoration(
                hintText: 'Số điện thoại',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronDown extends StatelessWidget {
  const _ChevronDown();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(10, 10),
        painter: _ChevronPainter(),
      );
}

class _ChevronPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = MpColors.text3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(1.5, 3.5)
        ..lineTo(5, 6.5)
        ..lineTo(8.5, 3.5),
      p,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter _) => false;
}

// ── Password checklist item ───────────────────────────────────────────────────

class _PasswordCheck extends StatelessWidget {
  const _PasswordCheck({required this.ok, required this.label});
  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomPaint(
          size: const Size(14, 14),
          painter: _CheckCirclePainter(ok: ok),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ok ? MpColors.green : MpColors.text3,
          ),
        ),
      ],
    );
  }
}

class _CheckCirclePainter extends CustomPainter {
  const _CheckCirclePainter({required this.ok});
  final bool ok;

  @override
  void paint(Canvas c, Size s) {
    final stroke = Paint()
      ..color = ok ? MpColors.green : MpColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final fill = Paint()
      ..color = ok ? MpColors.greenSoft : Colors.transparent
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(s.width / 2, s.height / 2), s.width / 2 - 0.4, fill);
    c.drawCircle(Offset(s.width / 2, s.height / 2), s.width / 2 - 0.4, stroke);
    if (ok) {
      final tick = Paint()
        ..color = MpColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      c.drawPath(
        Path()
          ..moveTo(3, 7)
          ..lineTo(5.5, 9.5)
          ..lineTo(10, 4.5),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckCirclePainter old) => old.ok != ok;
}

// ── Consent checkbox row ──────────────────────────────────────────────────────

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.child,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: value ? MpColors.text : MpColors.surface,
              border: Border.all(
                color: value ? MpColors.text : MpColors.borderStrong,
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: value
                ? const Center(child: _CheckMark())
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark();
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(10, 10),
        painter: _CheckMarkPainter(),
      );
}

class _CheckMarkPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = MpColors.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(1.5, 5)
        ..lineTo(3.8, 7.3)
        ..lineTo(8.5, 2.5),
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
          color: enabled
              ? MpColors.text
              : MpColors.text.withValues(alpha: 0.2),
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

// ── Eye icon ──────────────────────────────────────────────────────────────────

class _EyeIcon extends StatelessWidget {
  const _EyeIcon({required this.open});
  final bool open;
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(18, 18),
        painter: _EyeIconPainter(open: open),
      );
}

class _EyeIconPainter extends CustomPainter {
  const _EyeIconPainter({required this.open});
  final bool open;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = MpColors.text3
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final eye = Path()
      ..moveTo(1, 9)
      ..cubicTo(4, 4, 14, 4, 17, 9)
      ..cubicTo(14, 14, 4, 14, 1, 9);
    c.drawPath(eye, p);
    if (open) {
      c.drawCircle(const Offset(9, 9), 2.5, p);
    } else {
      c.drawPath(Path()..moveTo(2, 2)..lineTo(16, 16), p);
    }
  }

  @override
  bool shouldRepaint(_EyeIconPainter old) => old.open != open;
}
