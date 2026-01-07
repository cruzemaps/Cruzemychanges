import 'package:flutter_test/flutter_test.dart';
import 'package:cruze_mobile/main.dart';
import 'package:cruze_mobile/screens/login_screen.dart';

void main() {
  testWidgets('CruzeApp loads LoginScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CruzeApp());

    // Verify that LoginScreen is present
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('CRUZE'), findsOneWidget);
  });
}
