class SignupState {
  const SignupState({
    this.loading = false,
    this.error,
    this.pendingEmail,
    this.otpExpiresInSeconds = 0,
  });

  final bool loading;
  final String? error;
  final String? pendingEmail;
  final int otpExpiresInSeconds;

  SignupState copyWith({
    bool? loading,
    String? error,
    String? pendingEmail,
    int? otpExpiresInSeconds,
  }) {
    return SignupState(
      loading: loading ?? this.loading,
      error: error,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      otpExpiresInSeconds: otpExpiresInSeconds ?? this.otpExpiresInSeconds,
    );
  }
}
