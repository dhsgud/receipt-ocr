// Basic widget test for Receipt Ledger App
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_ledger/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build the app wrapped in ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: ReceiptLedgerApp(),
      ),
    );

    // Verify app loads without errors
    expect(find.text('홈'), findsOneWidget);
  });
}
