import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:muzilla/main.dart';
import 'package:muzilla/providers/song_library_provider.dart';

void main() {
  testWidgets('Muzilla ana sayfa açılıyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songLibraryProvider
              .overrideWith((ref) async => SongLibraryLoaded(const [])),
        ],
        child: const MuzillaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Muzilla'), findsOneWidget);
    expect(find.text('Henüz müzik yok'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });
}
