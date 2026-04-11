import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/calendar_provider.dart';
import 'router.dart';

// --dart-define=TEST_MODE=true 로 실행하면 테스트 계정 자동 로그인
const bool kTestMode = bool.fromEnvironment('TEST_MODE', defaultValue: false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');

  final authProvider = AuthProvider();

  if (kTestMode) {
    await authProvider.login('hk@test.com', 'test1234');
  } else {
    // 저장된 토큰 + 로컬 캐시된 user로 세션을 즉시 복원.
    // disk I/O만 await하며, /auth/me는 내부에서 unawaited로 백그라운드 실행.
    await authProvider.tryRestore();
  }

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

  @override
  void initState() {
    super.initState();
    // Router를 한 번만 생성. AuthProvider 변경은 refreshListenable이 반응하므로
    // 여기서 Consumer로 감싸 재생성할 필요가 없다.
    _router = createRouter(widget.authProvider);
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
