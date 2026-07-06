import 'package:flutter_native_events_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Flutter Native Events'), findsOneWidget);
  });
}
