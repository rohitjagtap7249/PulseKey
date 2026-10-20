import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsekey/main.dart';

void main() {
  testWidgets('shows the three tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const PulseKeyApp());
    expect(find.text('Alarm'), findsOneWidget);
    expect(find.text('Stopwatch'), findsOneWidget);
    expect(find.text('Timer'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
