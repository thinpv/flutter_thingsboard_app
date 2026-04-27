import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thingsboard_app/constants/app_constants.dart';

/// Public client for /mpipe/auth/* endpoints. These routes don't require a
/// ThingsBoard token because they run before the user exists. Response shape
/// matches middleware's model.VerifyResponse / RegisterResponse.
class AuthMiddlewareService {
  AuthMiddlewareService() : _base = _resolveMiddlewareBase();

  final String _base;

  static String _resolveMiddlewareBase() {
    const explicit = ThingsboardAppConstants.middlewareUrl;
    if (explicit.isNotEmpty) return explicit;
    final uri = Uri.parse(ThingsboardAppConstants.thingsBoardApiEndpoint);
    return '${uri.scheme}://${uri.host}/mpipe';
  }

  Future<RegisterResult> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final body = {
      'email': email,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    };
    final resp = await _post('/auth/register', body);
    return RegisterResult.fromJson(resp);
  }

  Future<RegisterResult> resendOtp(String email) async {
    final resp = await _post('/auth/resend-otp', {'email': email});
    return RegisterResult.fromJson(resp);
  }

  Future<VerifyResult> verify({required String email, required String otp}) async {
    final resp = await _post('/auth/verify', {'email': email, 'otp': otp});
    return VerifyResult.fromJson(resp);
  }

  /// Permanently deletes the authenticated CUSTOMER_USER account + the
  /// owning Customer entity (cascades home/room/device data). TB CE only
  /// allows admins to call DELETE /api/user/{id}, so this goes through the
  /// middleware which uses tenant credentials to satisfy the permission
  /// model after verifying the request came from the user themselves.
  ///
  /// `customerToken` is the live TB JWT — middleware.Auth re-verifies it
  /// against /api/auth/user before deleting.
  Future<void> deleteAccount(String customerToken) async {
    final resp = await http.delete(
      Uri.parse('$_base/auth/account'),
      headers: {'Authorization': 'Bearer $customerToken'},
    );
    if (resp.statusCode == 204 || resp.statusCode == 200) return;
    String msg = 'HTTP ${resp.statusCode}';
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        if (decoded['error'] is String) msg = decoded['error'] as String;
      } catch (_) {/* fall through */}
    }
    throw AuthMiddlewareException(resp.statusCode, msg);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse('$_base$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = resp.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final msg = decoded['error'] as String? ?? 'HTTP ${resp.statusCode}';
      throw AuthMiddlewareException(resp.statusCode, msg);
    }
    return decoded;
  }
}

class AuthMiddlewareException implements Exception {
  AuthMiddlewareException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class RegisterResult {
  RegisterResult({
    required this.email,
    required this.needsVerification,
    required this.expiresInSeconds,
  });

  factory RegisterResult.fromJson(Map<String, dynamic> j) => RegisterResult(
        email: j['email'] as String? ?? '',
        needsVerification: j['needsVerification'] as bool? ?? true,
        expiresInSeconds: j['expiresInSeconds'] as int? ?? 600,
      );

  final String email;
  final bool needsVerification;
  final int expiresInSeconds;
}

class VerifyResult {
  VerifyResult({
    required this.token,
    required this.refreshToken,
    required this.userId,
    required this.customerId,
  });

  factory VerifyResult.fromJson(Map<String, dynamic> j) => VerifyResult(
        token: j['token'] as String? ?? '',
        refreshToken: j['refreshToken'] as String? ?? '',
        userId: j['userId'] as String? ?? '',
        customerId: j['customerId'] as String? ?? '',
      );

  final String token;
  final String refreshToken;
  final String userId;
  final String customerId;
}
