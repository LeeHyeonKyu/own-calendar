import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:home_widget/home_widget.dart';
import 'providers/auth_provider.dart';
import 'providers/calendar_provider.dart';
import 'router.dart';
import 'services/fcm_service.dart';

// --dart-define=TEST_MODE=true 로 실행하면 테스트 계정 자동 로그인
const bool kTestMode = bool.fromEnvironment('TEST_MODE', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  try {
    await HomeWidget.setAppGroupId('group.com.owncalendar.ownCalendar');
  } catch (_) {}

  final authProvider = AuthProvider();

  if (kTestMode) {
    await authProvider.login('hk@test.com', 'test1234');
  } else {
    // 저장된 토큰 + 로컬 캐시된 user로 세션을 즉시 복원.
    // disk I/O만 await하며, /auth/me는 내부에서 unawaited로 백그라운드 실행.
    await authProvider.tryRestore();
  }

  // Initialize FCM for push notifications (no-op until Firebase is configured)
  unawaited(FcmService().initialize());

  runApp(OwnCalendarApp(authProvider: authProvider));
}

class OwnCalendarApp extends StatefulWidget {
  final AuthProvider authProvider;

  const OwnCalendarApp({super.key, required this.authProvider});

  @override
  State<OwnCalendarApp> createState() => _OwnCalendarAppState();
}

class _OwnCalendarAppState extends State<OwnCalendarApp> {
  late final GoRouter _router;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    // Router를 한 번만 생성. AuthProvider 변경은 refreshListenable이 반응하므로
    // 여기서 Consumer로 감싸 재생성할 필요가 없다.
    _router = createRouter(widget.authProvider);

    try {
      _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    } catch (_) {}
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    // owncalendar://monthly → host = "monthly", path = ""
    // owncalendar://add?date=2026-09-01 → host = "add", query = "date=2026-09-01"
    // owncalendar://event/abc123 → host = "event", path = "/abc123"
    final action = uri.host;
    switch (action) {
      case 'monthly':
        _router.go('/');
        break;
      case 'add':
        final date = uri.queryParameters['date'];
        _router.go(date != null ? '/event/new?date=$date' : '/event/new');
        break;
      case 'event':
        final id =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (id != null) {
          _router.go('/event/$id/edit');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: MaterialApp.router(
        title: 'Own Calendar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        routerConfig: _router,
      ),
    );
  }
}
