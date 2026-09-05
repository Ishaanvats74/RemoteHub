import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_ctrl/main.dart';

void main() {
  testWidgets('App renders splash screen and brand title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RemoteCtrlApp(),
      ),
    );

    // Verify brand title and tagline render
    expect(find.text('RemoteCtrl'), findsOneWidget);
    expect(find.text('Secure Remote Power & Machine Control'), findsOneWidget);
  });
}
