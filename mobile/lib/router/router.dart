import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Route provider — screen implementations are added in later phases.
/// All routes currently render a [_PlaceholderScreen] stub.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _PlaceholderScreen(title: 'Splash'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const _PlaceholderScreen(title: 'Login'),
      ),
      GoRoute(
        path: '/devices',
        builder: (_, __) => const _PlaceholderScreen(title: 'Devices'),
        routes: [
          GoRoute(
            path: 'pair',
            builder: (_, __) => const _PlaceholderScreen(title: 'Pair Device'),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => _PlaceholderScreen(
              title: 'Device ${state.pathParameters['id']}',
            ),
            routes: [
              GoRoute(
                path: 'history',
                builder: (_, state) => _PlaceholderScreen(
                  title: 'History ${state.pathParameters['id']}',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Temporary placeholder used until each feature screen is implemented.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title\n(coming in a future phase)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

