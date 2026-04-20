import 'package:go_router/go_router.dart';
import 'package:thingsboard_app/modules/smarthome/home/presentation/home_tab.dart';
import 'package:thingsboard_app/modules/smarthome/profile/presentation/profile_tab.dart';
import 'package:thingsboard_app/modules/smarthome/smart/presentation/smart_tab.dart';
import 'package:thingsboard_app/modules/smarthome/smarthome_shell.dart';

abstract final class SmarthomeRoutes {
  static const home = '/smarthome/home';
  static const smart = '/smarthome/smart';
  static const profile = '/smarthome/profile';
}

List<RouteBase> getSmarthomeRoutes() {
  return [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return SmartHomeShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: SmarthomeRoutes.home,
              builder: (context, state) => const HomeTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: SmarthomeRoutes.smart,
              builder: (context, state) => const SmartTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: SmarthomeRoutes.profile,
              builder: (context, state) => const ProfileTab(),
            ),
          ],
        ),
      ],
    ),
  ];
}
