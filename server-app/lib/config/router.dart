import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/views/login_screen.dart';
import '../features/auth/views/splash_screen.dart';
import '../features/dashboard/views/dashboard_screen.dart';
import '../features/locations/views/place_details_screen.dart';
import '../features/locations/views/places_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, _) => const DashboardScreen(),
        routes: [
          GoRoute(
            path: 'spaces',
            builder: (context, _) => const PlacesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final idParam = state.pathParameters['id'] ?? '0';
                  final id = int.tryParse(idParam) ?? 0;
                  return PlaceDetailsScreen(spaceId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final bool isLoading = authState.isLoading;
      final session = authState.valueOrNull;
      final bool loggingIn = state.matchedLocation == '/login';
      final bool atSplash = state.matchedLocation == '/splash';

      if (isLoading) {
        return atSplash ? null : '/splash';
      }

      if (session == null) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn || atSplash) {
        return '/dashboard';
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(state.error?.toString() ?? 'Unexpected error'),
      ),
    ),
  );
});
