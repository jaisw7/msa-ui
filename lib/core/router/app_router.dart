/// App router configuration using GoRouter.
library;

import 'package:go_router/go_router.dart';

import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/positions/positions_screen.dart';
import '../../presentation/screens/performance/performance_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/stock/stock_detail_screen.dart';
import '../../presentation/widgets/app_shell.dart';

/// Route paths.
abstract final class AppRoutes {
  static const String home = '/';
  static const String positions = '/positions';
  static const String performance = '/performance';
  static const String settings = '/settings';
  static const String stock = '/stock/:ticker';

  static String stockDetail(String ticker) => '/stock/$ticker';
}

/// App router configuration.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.positions,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PositionsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.performance,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PerformanceScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    // Stock detail outside shell (full screen)
    GoRoute(
      path: AppRoutes.stock,
      builder: (context, state) {
        final ticker = state.pathParameters['ticker']!;
        return StockDetailScreen(ticker: ticker);
      },
    ),
  ],
);
