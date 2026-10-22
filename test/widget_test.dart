import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsekey/main.dart';

void main() {
  testWidgets('shows the timer screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TimerApp());
    expect(find.text('Frequently used timers'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
