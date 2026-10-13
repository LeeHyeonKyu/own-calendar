import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/monthly_view_screen.dart';
import 'screens/daily_view_screen.dart';
import 'screens/weekly_view_screen.dart';
import 'screens/yearly_view_screen.dart';
import 'screens/family_screen.dart';
import 'models/event.dart';
import 'screens/event_form_screen.dart';
import 'screens/task_form_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tab_settings_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'screens/category_settings_screen.dart';
import 'screens/holiday_settings_screen.dart';
import 'screens/import_screen.dart';
import 'screens/group_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/follow_search_screen.dart';
import 'widgets/navigation_shell.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    // AuthProvider(ChangeNotifier)의 notifyListeners가 호출될 때마다 redirect가
    // 재평가된다. 자동 로그인 복원, 백그라운드 hydrate 실패, 명시적 로그아웃
    // 모두 이 한 줄로 반응한다.
    refreshListenable: authProvider,
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

      // ── Shell: all main screens share the centralized bottom nav + FAB ──
      ShellRoute(
        builder: (context, state, child) => NavigationShell(
          state: state,
          child: child,
        ),
        routes: [
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
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ──
      GoRoute(
        path: '/event/new',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is EventModel) {
            return EventFormScreen(template: extra);
          }
          DateTime? date;
          if (extra is DateTime) {
            date = extra;
          } else {
            final dateStr = state.uri.queryParameters['date'];
            date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          }
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
        path: '/task/new',
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          final eventId = state.uri.queryParameters['eventId'];
          return TaskFormScreen(initialDate: date, initialEventId: eventId);
        },
      ),
      GoRoute(
        path: '/task/:id/edit',
        builder: (context, state) => TaskFormScreen(
          taskId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/settings/tabs',
        builder: (context, state) => const TabSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/theme',
        builder: (context, state) => const ThemeSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/categories',
        builder: (context, state) => const CategorySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/holidays',
        builder: (context, state) => const HolidaySettingsScreen(),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => const ImportScreen(),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) => GroupDetailScreen(
          groupId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/follow/search',
        builder: (context, state) => const FollowSearchScreen(),
      ),

      // Deep link routes for widget interactions
      GoRoute(
        path: '/add',
        redirect: (context, state) {
          final date = state.uri.queryParameters['date'];
          return date != null ? '/event/new?date=$date' : '/event/new';
        },
      ),
      GoRoute(
        path: '/monthly',
        redirect: (context, state) => '/',
      ),
    ],
  );
}
