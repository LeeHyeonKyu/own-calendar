import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/monthly_view_screen.dart';
import 'screens/daily_view_screen.dart';
import 'screens/weekly_view_screen.dart';
import 'screens/yearly_view_screen.dart';
import 'screens/family_screen.dart';
import 'screens/event_form_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) return '/login';
      if (isAuthenticated && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final monthStr = state.uri.queryParameters['month'];
          final month = monthStr != null ? DateTime.tryParse(monthStr) : null;
          return MonthlyViewScreen(initialMonth: month);
        },
      ),
      GoRoute(
        path: '/daily',
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          return DailyViewScreen(initialDate: date);
        },
      ),
      GoRoute(
        path: '/weekly',
        builder: (context, state) => const WeeklyViewScreen(),
      ),
      GoRoute(
        path: '/yearly',
        builder: (context, state) => const YearlyViewScreen(),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyScreen(),
      ),
      GoRoute(
        path: '/event/new',
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          return EventFormScreen(initialDate: date);
        },
      ),
      GoRoute(
        path: '/event/:id/edit',
        builder: (context, state) => EventFormScreen(
          eventId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
