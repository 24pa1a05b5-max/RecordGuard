import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/shared/widgets/app_scaffold.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/features/dashboard/dashboard_screen.dart';
import 'package:frontend/features/patients/patients_screen.dart';
import 'package:frontend/features/patients/patient_detail_screen.dart';
import 'package:frontend/features/compare/compare_screen.dart';
import 'package:frontend/features/workspace/workspace_screen.dart';
import 'package:frontend/features/queue/queue_screen.dart';
import 'package:frontend/features/model_info/model_info_screen.dart';
import 'package:frontend/features/settings/settings_screen.dart';
import 'package:frontend/features/account/account_screen.dart';
import 'package:frontend/features/admin/admin_screen.dart';
import 'package:frontend/providers/app_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoginRoute = state.matchedLocation == '/login';
      final isLoggedIn = user != null;

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (isLoggedIn && isLoginRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(currentRoute: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientsScreen(),
          ),
          GoRoute(
            path: '/patients/:id',
            builder: (context, state) =>
                PatientDetailScreen(patientId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/compare',
            builder: (context, state) => const CompareScreen(),
          ),
          GoRoute(
            path: '/workspace',
            builder: (context, state) => const WorkspaceScreen(),
          ),
          GoRoute(
            path: '/queue',
            builder: (context, state) => const QueueScreen(),
          ),
          GoRoute(
            path: '/model-info',
            builder: (context, state) => const ModelInfoScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
    ],
  );
});

// Backward-compatible fallback router
final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) {
        return AppScaffold(currentRoute: state.matchedLocation, child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/patients',
          builder: (context, state) => const PatientsScreen(),
        ),
        GoRoute(
          path: '/patients/:id',
          builder: (context, state) =>
              PatientDetailScreen(patientId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/compare',
          builder: (context, state) => const CompareScreen(),
        ),
        GoRoute(
          path: '/workspace',
          builder: (context, state) => const WorkspaceScreen(),
        ),
        GoRoute(
          path: '/queue',
          builder: (context, state) => const QueueScreen(),
        ),
        GoRoute(
          path: '/model-info',
          builder: (context, state) => const ModelInfoScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => const AccountScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminScreen(),
        ),
      ],
    ),
  ],
);
