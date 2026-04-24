import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:thingsboard_app/core/auth/signup/models/signup_state.dart';
import 'package:thingsboard_app/locator.dart';
import 'package:thingsboard_app/utils/services/smarthome/auth_middleware_service.dart';
import 'package:thingsboard_app/utils/services/tb_client_service/i_tb_client_service.dart';

class SignupNotifier extends StateNotifier<SignupState> {
  SignupNotifier() : super(const SignupState());

  final _auth = AuthMiddlewareService();

  /// Step 1 — POST /auth/register. Returns email on success so the caller
  /// can navigate to the OTP page with it.
  Future<String> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _auth.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      state = state.copyWith(
        loading: false,
        pendingEmail: res.email,
        otpExpiresInSeconds: res.expiresInSeconds,
      );
      return res.email;
    } on AuthMiddlewareException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Không thể gửi mã xác thực');
      rethrow;
    }
  }

  /// Step 2 — POST /auth/verify + auto-login with returned tokens.
  /// Returns true if the user is now authenticated with ThingsBoard.
  Future<bool> verifyAndLogin({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _auth.verify(email: email, otp: otp);
      final tbClient = getIt<ITbClientService>().client;
      await tbClient.setUserFromJwtToken(
        res.token,
        res.refreshToken,
        /* notify = */ true,
      );
      state = state.copyWith(loading: false);
      return true;
    } on AuthMiddlewareException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Xác thực thất bại');
      return false;
    }
  }

  /// Resend OTP for the pending email.
  Future<bool> resendOtp(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _auth.resendOtp(email);
      state = state.copyWith(
        loading: false,
        otpExpiresInSeconds: res.expiresInSeconds,
      );
      return true;
    } on AuthMiddlewareException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Không thể gửi lại mã');
      return false;
    }
  }
}

final signupProvider =
    StateNotifierProvider.autoDispose<SignupNotifier, SignupState>(
  (ref) => SignupNotifier(),
);
