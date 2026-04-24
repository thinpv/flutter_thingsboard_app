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

class SignupPage extends HookConsumerWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = useMemoized(
      () => FormGroup({
        'email': FormControl<String>(
          validators: [Validators.required, Validators.email],
        ),
        'password': FormControl<String>(
          validators: [Validators.required, Validators.minLength(8)],
        ),
        'firstName': FormControl<String>(),
        'lastName': FormControl<String>(),
      }),
    );
    final state = ref.watch(signupProvider);
    final showPassword = useState(false);

    return Scaffold(
      appBar: TbAppBar(title: const Text('Đăng ký tài khoản')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: ReactiveForm(
              formGroup: form,
              child: SingleChildScrollView(
                child: Column(
                  spacing: 20,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nhập email và mật khẩu để tạo tài khoản. Chúng tôi sẽ gửi một mã xác thực 6 số đến email của bạn.',
                      textAlign: TextAlign.center,
                      style: TbTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TbTextField(
                      formControlName: 'email',
                      label: 'Email',
                      type: TextInputType.emailAddress,
                      autoFillHints: const [AutofillHints.email],
                    ),
                    TbTextField(
                      formControlName: 'password',
                      label: 'Mật khẩu (tối thiểu 8 ký tự)',
                      obscureText: !showPassword.value,
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword.value
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            showPassword.value = !showPassword.value,
                      ),
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: TbTextField(
                            formControlName: 'firstName',
                            label: 'Tên',
                          ),
                        ),
                        Expanded(
                          child: TbTextField(
                            formControlName: 'lastName',
                            label: 'Họ',
                          ),
                        ),
                      ],
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
                              : () => _onSubmit(context, ref, form),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Gửi mã xác thực'),
                        );
                      },
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
    final email = (form.control('email').value as String).trim().toLowerCase();
    final password = form.control('password').value as String;
    final firstName = form.control('firstName').value as String?;
    final lastName = form.control('lastName').value as String?;
    try {
      await ref.read(signupProvider.notifier).register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
          );
      if (context.mounted) {
        context.push('/login/otpVerify', extra: email);
      }
    } catch (_) {
      // error already on state
    }
  }
}
