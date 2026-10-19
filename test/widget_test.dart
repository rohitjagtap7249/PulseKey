import 'package:flutter_test/flutter_test.dart';
import 'package:pulsekey/main.dart';

void main() {
  testWidgets('shows PulseKey title', (WidgetTester tester) async {
    await tester.pumpWidget(const PulseKeyApp());
    expect(find.text('PulseKey'), findsOneWidget);
  });
}
