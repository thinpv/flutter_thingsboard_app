import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:thingsboard_app/config/themes/app_colors.dart';
import 'package:thingsboard_app/config/themes/tb_text_styles.dart';
import 'package:thingsboard_app/core/auth/login/widgets/full_screen_loader.dart';
import 'package:thingsboard_app/core/auth/login/widgets/text_field.dart';
import 'package:thingsboard_app/core/auth/signup/provider/signup_provider.dart';
import 'package:thingsboard_app/utils/ui/visibility_widget.dart';
import 'package:thingsboard_app/widgets/tb_app_bar.dart';

class OtpVerifyPage extends HookConsumerWidget {
  const OtpVerifyPage({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = useMemoized(
      () => FormGroup({
        'otp': FormControl<String>(
          validators: [
            Validators.required,
            Validators.pattern(r'^\d{6}$'),
          ],
        ),
      }),
    );
    final state = ref.watch(signupProvider);

    return Scaffold(
      appBar: TbAppBar(title: const Text('Xác thực email')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: ReactiveForm(
              formGroup: form,
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nhập mã 6 số đã gửi tới $email',
                    textAlign: TextAlign.center,
                    style: TbTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  TbTextField(
                    formControlName: 'otp',
                    label: 'Mã xác thực',
                    type: TextInputType.number,
                    autoFocus: true,
                  ),
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TbTextStyles.bodyMedium.copyWith(
                        color: AppColors.textError,
                      ),
                    ),
                  const SizedBox(height: 8),
                  ReactiveFormConsumer(
                    builder: (context, formGroup, _) {
                      return ElevatedButton(
                        onPressed: formGroup.invalid || state.loading
                            ? null
                            : () => _onVerify(context, ref, form),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Xác thực và đăng nhập'),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: state.loading
                        ? null
                        : () => _onResend(context, ref),
                    child: const Text('Gửi lại mã'),
                  ),
                ],
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

  Future<void> _onVerify(
      BuildContext context, WidgetRef ref, FormGroup form) async {
    FocusScope.of(context).unfocus();
    form.markAllAsTouched();
    if (form.invalid) return;
    final otp = form.control('otp').value as String;
    final ok = await ref
        .read(signupProvider.notifier)
        .verifyAndLogin(email: email, otp: otp);
    if (ok && context.mounted) {
      // setUserFromJwtToken triggers UserLoadedEvent → LoginNotifier fully
      // logs in and redirects. Pop the signup stack so back button goes home.
      while (context.canPop()) {
        context.pop();
      }
    }
  }

  Future<void> _onResend(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(signupProvider.notifier).resendOtp(email);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi lại mã xác thực')),
      );
    }
  }
}
