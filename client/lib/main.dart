import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  }

  runApp(OwnCalendarApp(authProvider: authProvider));
}

class OwnCalendarApp extends StatelessWidget {
  final AuthProvider authProvider;

  const OwnCalendarApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final router = createRouter(auth);
          return MaterialApp.router(
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
            routerConfig: router,
          );
        },
      ),
    );
  }
}
