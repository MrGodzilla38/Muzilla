import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzilla/providers/song_library_provider.dart';
import 'package:muzilla/screens/home_screen.dart';
import 'package:on_audio_query/on_audio_query.dart';

void main() {
  testWidgets('empty library shows home with category tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songLibraryProvider.overrideWith(
            (ref) async => SongLibraryLoaded(const <SongModel>[]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Muzilla'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Yeni Eklenenler'), findsWidgets);
    expect(find.text('Henüz müzik yok'), findsOneWidget);
    expect(find.text('Yenile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home renders sections with songs', (tester) async {
    final songs = List.generate(
      8,
      (i) => SongModel({
        '_id': i + 1,
        '_data': '/tmp/song$i.mp3',
        '_display_name': 'Şarkı $i',
        '_display_name_wo_ext': 'Şarkı $i',
        '_size': 1024,
        'title': 'Şarkı $i',
        'artist': 'Sanatçı $i',
        'duration': 200000,
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songLibraryProvider.overrideWith((ref) async => SongLibraryLoaded(songs)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sık Kullanılanların'), findsOneWidget);
    expect(find.text('En Son Oynatılanlar'), findsOneWidget);
    expect(find.text('Karıştır'), findsOneWidget);
    expect(find.text('Oynat'), findsOneWidget);
    expect(find.text('Tümü'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('HAFTALIK KEŞİF •'), findsOneWidget);
    expect(find.text('Sana Özel Akış Hazır'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
