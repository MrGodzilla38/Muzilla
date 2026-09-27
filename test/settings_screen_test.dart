import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzilla/providers/settings_provider.dart';
import 'package:muzilla/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(WidgetTester tester) async {
  final element = tester.element(find.byType(SettingsScreen));
  return ProviderScope.containerOf(element);
}

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: SettingsScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('anahtarlar provider durumunu değiştirir', (tester) async {
    await _pumpSettings(tester);
    final container = await _container(tester);

    expect(find.text('Otomatik karıştır'), findsOneWidget);
    expect(find.text('Kesintisiz çalma'), findsOneWidget);
    expect(find.text('Geçiş efektleri'), findsOneWidget);
    expect(container.read(settingsProvider).autoShuffle, isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).autoShuffle, isTrue);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).gapless, isFalse);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).crossfade, isFalse);

    // Kapatıp yeniden açınca da durum korunur (aynı ProviderScope).
    expect(container.read(settingsProvider).autoShuffle, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uyku zamanlayıcı seçimi gerçekten çalışır', (tester) async {
    await _pumpSettings(tester);
    final container = await _container(tester);

    expect(container.read(settingsProvider).sleepMode, SleepTimerMode.off);
    expect(find.text('Kapalı'), findsOneWidget);

    await tester.tap(find.text('Uyku zamanlayıcı'));
    await tester.pumpAndSettle();
    expect(find.text('Uyku zamanlayıcı'), findsWidgets);

    await tester.tap(find.widgetWithText(RadioListTile<String>, 'Şarkı sonunda'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).sleepMode,
        SleepTimerMode.songEnd);
    expect(find.text('Şarkı sonunda'), findsOneWidget);

    // Geri açıp "Kapalı" seçince kapanır.
    await tester.tap(find.text('Uyku zamanlayıcı'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<String>, 'Kapalı').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).sleepMode, SleepTimerMode.off);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekolayzır preset seçimi ve kaydırıcılar çalışır',
      (tester) async {
    await _pumpSettings(tester);
    final container = await _container(tester);

    expect(container.read(settingsProvider).equalizerPresetId, 'flat');
    expect(find.text('Ekolayzır'), findsOneWidget);

    await tester.tap(find.text('Ekolayzır'));
    await tester.pumpAndSettle();

    expect(find.text('Ekolayzır'), findsNWidgets(2)); // satır + sayfa başlığı

    final sheet = find.byKey(const ValueKey<String>('equalizerSheet'));
    final sheetSliders =
        find.descendant(of: sheet, matching: find.byType(Slider));
    expect(sheetSliders, findsNWidgets(5));

    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).equalizerPresetId, 'rock');

    // Kaydırıcıyı oynatınca "Özel" presetine geçer.
    await tester.drag(sheetSliders.first, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).equalizerPresetId,
        customEqualizerPresetId);

    await tester.tap(find.text('Dans'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).equalizerPresetId, 'dance');
    expect(tester.takeException(), isNull);
  });

  testWidgets('geçiş süresi barı yalnızca efekt açıkken görünür',
      (tester) async {
    await _pumpSettings(tester);
    final container = await _container(tester);

    expect(container.read(settingsProvider).crossfadeSeconds, 1.5);
    expect(find.text('Geçiş süresi'), findsOneWidget);
    expect(find.text('1,5 sn'), findsOneWidget);

    final slider = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Slider),
    );
    expect(slider, findsOneWidget);

    await tester.drag(slider, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).crossfadeSeconds,
      greaterThan(1.5),
    );
    expect(find.text('Geçiş süresi'), findsOneWidget);

    // Efekt kapatılınca süre barı kaybolur.
    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).crossfade, isFalse);
    expect(find.text('Geçiş süresi'), findsNothing);
    expect(slider, findsNothing);

    // Yeniden açılınca geri gelir ve seçim korunur.
    final savedSeconds = container.read(settingsProvider).crossfadeSeconds;
    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Geçiş süresi'), findsOneWidget);
    expect(container.read(settingsProvider).crossfadeSeconds, savedSeconds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('her ayarın altında açıklama metni var', (tester) async {
    await _pumpSettings(tester);

    expect(
      find.text('Yeni liste başlarken karıştırmayı otomatik açar.'),
      findsOneWidget,
    );
    expect(
      find.text('Kapalıyken şarkılar arasına 1,5 sn sessizlik girer.'),
      findsOneWidget,
    );
    expect(
      find.text('Şarkı geçişlerinde sesi kısıp açarak yumuşak geçiş yapar.'),
      findsOneWidget,
    );
    expect(
      find.text('Süre dolunca ya da şarkı bitince müziği duraklatır.'),
      findsOneWidget,
    );
    expect(
      find.text('Bas, tiz ve ses rengini preset ya da kaydırıcılarla ayarlarsın.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('kalite satırı kaldırıldı, hakkında bölümü duruyor',
      (tester) async {
    await _pumpSettings(tester);

    expect(find.text('Çalma kalitesi'), findsNothing);

    // Açıklamalar yüzünden bölüm ekranın altına düştü; oraya kaydır.
    await tester.scrollUntilVisible(
      find.text('HAKKINDA'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('HAKKINDA'), findsOneWidget);
    expect(find.text('Muzilla'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });
}
