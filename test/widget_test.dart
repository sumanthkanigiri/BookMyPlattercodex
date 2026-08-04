import 'package:bookmyplatter/src/app/book_my_platter_app.dart';
import 'package:bookmyplatter/src/features/splash/presentation/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders BookMyPlatter app shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [startupProvider.overrideWith((ref) async => false)],
        child: const BookMyPlatterApp(),
      ),
    );
    expect(find.text('BookMyPlatter'), findsOneWidget);
  });
}
