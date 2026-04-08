import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';
import 'package:thingsboard_app/config/routes/v2/redirects/redirect.dart';
import 'package:thingsboard_app/config/routes/v2/routes_config/routes/smarthome_routes.dart';
import 'package:thingsboard_app/core/auth/login/provider/login_provider.dart';
import 'package:thingsboard_app/core/auth/redirect/auth_redirect.dart';
import 'package:thingsboard_app/thingsboard_client.dart';

/// Redirects CUSTOMER_USER to the SmartHome section.
/// Any path that is not /smarthome/* (and not login) will be sent to /smarthome/home.
class SmarthomeRedirect implements Redirect {
  @override
  Future<String?> redirect(
    BuildContext context,
    GoRouterState state,
    Ref ref,
  ) async {
    final login = ref.read(loginProvider);

    if (!login.isUserLoaded) return null;
    if (login.userScope != Authority.CUSTOMER_USER) return null;
    if (isLoginPath(state)) return null;

    final path = state.uri.path;
    if (!path.startsWith('/smarthome')) {
      return SmarthomeRoutes.home;
    }
    return null;
  }
}
