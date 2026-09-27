import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzilla/providers/song_library_provider.dart';
import 'package:muzilla/screens/home_screen.dart';
import 'package:muzilla/widgets/song_tile.dart';
import 'package:on_audio_query/on_audio_query.dart';

List<SongModel> _buildSongs(List<String> titles) {
  return [
    for (var i = 0; i < titles.length; i++)
      SongModel({
        '_id': i + 1,
        '_data': '/tmp/song$i.mp3',
        '_display_name': titles[i],
        '_display_name_wo_ext': titles[i],
        '_size': 1024,
        'title': titles[i],
        'artist': 'Sanatçı $i',
        'duration': 200000,
      }),
  ];
}

Future<void> _pumpHome(WidgetTester tester, List<SongModel> songs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songLibraryProvider.overrideWith((ref) async => SongLibraryLoaded(songs)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

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
    expect(find.text('Şarkılar'), findsOneWidget);
    expect(find.text('Kütüphane'), findsOneWidget);
    expect(find.text('Çalma listeleri'), findsOneWidget);
    expect(find.text('Sık Çalınanlar'), findsNothing);
    expect(find.text('Henüz müzik yok'), findsOneWidget);
    expect(find.text('Yenile'), findsOneWidget);
    expect(find.text('Karıştır'), findsOneWidget);
    expect(find.text('Oynat'), findsOneWidget);

    await tester.tap(find.text('Karıştır'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Müzik bulunamadı'), findsOneWidget);

    await tester.tap(find.text('Oynat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Müzik bulunamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home renders sections with songs', (tester) async {
    final songs = _buildSongs(List.generate(8, (i) => 'Şarkı $i'));

    await _pumpHome(tester, songs);

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

  testWidgets('Şarkılar lists every song alphabetically top to bottom',
      (tester) async {
    await _pumpHome(tester, _buildSongs(['Gamma', 'Alfa', 'Beta']));

    await tester.tap(find.text('Şarkılar'));
    await tester.pumpAndSettle();

    expect(find.byType(SongTile), findsNWidgets(3));
    expect(find.text('Sık Kullanılanların'), findsNothing);
    expect(find.text('En Son Oynatılanlar'), findsNothing);
    expect(find.text('Karıştır'), findsOneWidget);
    expect(find.text('Oynat'), findsOneWidget);

    final alfaY = tester.getTopLeft(find.text('Alfa')).dy;
    final betaY = tester.getTopLeft(find.text('Beta')).dy;
    final gammaY = tester.getTopLeft(find.text('Gamma')).dy;
    expect(alfaY < betaY, isTrue);
    expect(betaY < gammaY, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kütüphane category stays empty', (tester) async {
    await _pumpHome(tester, _buildSongs(['Alfa', 'Beta']));

    await tester.tap(find.text('Kütüphane'));
    await tester.pumpAndSettle();

    expect(find.byType(SongTile), findsNothing);
    expect(find.text('Sık Kullanılanların'), findsNothing);
    expect(find.text('HAFTALIK KEŞİF •'), findsNothing);
    expect(find.text('Karıştır'), findsOneWidget);
    expect(find.text('Oynat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
