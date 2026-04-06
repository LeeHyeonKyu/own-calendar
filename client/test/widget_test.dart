import 'package:flutter_test/flutter_test.dart';
import 'package:own_calendar/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const OwnCalendarApp());
    expect(find.text('Own Calendar'), findsAny);
  });
}
