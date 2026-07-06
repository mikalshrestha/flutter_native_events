import 'package:flutter_native_events_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows event bus actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Flutter Native Events'), findsOneWidget);
    expect(find.text('Emit logout'), findsOneWidget);
    expect(find.text('once() payment'), findsOneWidget);
    expect(find.text('Request account'), findsOneWidget);
    expect(find.text('Error reply'), findsOneWidget);
    expect(find.text('Timeout'), findsOneWidget);
  });
}
