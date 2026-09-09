import 'package:flutter_test/flutter_test.dart';
import 'package:own_calendar/main.dart';
import 'package:own_calendar/providers/auth_provider.dart';
import 'package:own_calendar/providers/theme_provider.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(OwnCalendarApp(
      authProvider: AuthProvider(),
      themeProvider: ThemeProvider(),
    ));
    expect(find.text('Own Calendar'), findsAny);
  });
}
