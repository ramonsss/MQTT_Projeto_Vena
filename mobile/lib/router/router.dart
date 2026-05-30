import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/live/presentation/device_detail_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/pairing/presentation/pair_screen.dart';

/// Bridges [authNotifierProvider] (Riverpod) → [Listenable] (GoRouter).
///
/// GoRouter's [refreshListenable] fires [redirect] whenever the notifier
/// changes, so the redirect runs on every auth state transition.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (_, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;

      // Auth check in progress — stay on splash while loading.
      if (isLoading) return loc == '/splash' ? null : '/splash';

      // Not authenticated — send to login.
      if (!isLoggedIn) return loc == '/login' ? null : '/login';

      // Authenticated but still on splash/login — go to devices.
      if (loc == '/splash' || loc == '/login') return '/devices';

      return null; // no redirect needed
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (_, __) => const DevicesScreen(),
        routes: [
          GoRoute(
            path: 'pair',
            builder: (_, __) => const PairScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => DeviceDetailScreen(
              deviceId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'history',
                builder: (_, state) => HistoryScreen(
                  deviceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});


