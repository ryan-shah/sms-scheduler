import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/diagnostics/diagnostics_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/schedules/schedules_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'scaffold_with_nav_bar.dart';

abstract final class AppRoutes {
  static const String schedules = '/';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String diagnostics = '/diagnostics';
}

GoRouter createAppRouter() => GoRouter(
  initialLocation: AppRoutes.schedules,
  routes: [
    GoRoute(
      path: AppRoutes.diagnostics,
      builder: (context, state) => const DiagnosticsScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNavBar(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.schedules,
              builder: (context, state) => const SchedulesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.history,
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// One router per [ProviderScope], so tests never share navigation state.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
