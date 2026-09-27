import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzilla/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsState> _waitFor(
  ProviderContainer container,
  bool Function(SettingsState state) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate(container.read(settingsProvider))) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Beklenen ayar durumuna ulaşılamadı.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(settingsProvider);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('varsayılan ayarlar makul', () async {
    final container = ProviderContainer.test();
    final state = container.read(settingsProvider);

    expect(state.autoShuffle, isFalse);
    expect(state.gapless, isTrue);
    expect(state.crossfade, isTrue);
    expect(state.sleepMode, SleepTimerMode.off);
    expect(state.sleepActive, isFalse);
    expect(state.equalizerPresetId, 'flat');
    expect(state.equalizerPresetLabel, 'Dengeli');
  });

  test('anahtar ayarları kalıcıdır', () async {
    final first = ProviderContainer.test();
    final notifier = first.read(settingsProvider.notifier);

    await notifier.setAutoShuffle(true);
    await notifier.setGapless(false);
    await notifier.setCrossfade(false);

    expect(first.read(settingsProvider).autoShuffle, isTrue);
    expect(first.read(settingsProvider).gapless, isFalse);
    expect(first.read(settingsProvider).crossfade, isFalse);

    final second = ProviderContainer.test();
    final restored = await _waitFor(second, (s) => s.autoShuffle);

    expect(restored.gapless, isFalse);
    expect(restored.crossfade, isFalse);
  });

  test('uyku zamanlayıcı modları çalışır ve kalıcıdır', () async {
    final container = ProviderContainer.test();
    final notifier = container.read(settingsProvider.notifier);

    await notifier.setSleepTimerDuration(30);
    var state = container.read(settingsProvider);
    expect(state.sleepMode, SleepTimerMode.timed);
    expect(state.sleepActive, isTrue);
    expect(state.sleepMinutes, 30);
    expect(state.sleepEndsAt, isNotNull);
    expect(
      state.sleepRemaining,
      greaterThan(const Duration(minutes: 29)),
    );

    await notifier.setSleepTimerOnSongEnd();
    state = container.read(settingsProvider);
    expect(state.sleepMode, SleepTimerMode.songEnd);
    expect(state.sleepEndsAt, isNull);

    final restored = ProviderContainer.test();
    final songEndRestored =
        await _waitFor(restored, (s) => s.sleepMode == SleepTimerMode.songEnd);
    expect(songEndRestored.sleepMode, SleepTimerMode.songEnd);

    await notifier.clearSleepTimer();
    expect(container.read(settingsProvider).sleepMode, SleepTimerMode.off);
    expect(container.read(settingsProvider).sleepActive, isFalse);
  });

  test('süreli zamanlayıcı uygulama yeniden açıldığında geri yüklenir',
      () async {
    final first = ProviderContainer.test();
    await first
        .read(settingsProvider.notifier)
        .setSleepTimerDuration(45);
    expect(first.read(settingsProvider).sleepMode, SleepTimerMode.timed);

    final second = ProviderContainer.test();
    final restored =
        await _waitFor(second, (s) => s.sleepMode == SleepTimerMode.timed);

    expect(restored.sleepMinutes, 45);
    expect(restored.sleepEndsAt, isNotNull);
    expect(
      restored.sleepRemaining,
      greaterThan(const Duration(minutes: 44)),
    );
    await second.read(settingsProvider.notifier).clearSleepTimer();
  });

  test('geçmişte biten zamanlayıcı geri yüklenmez', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.auto_shuffle': true,
      'settings.sleep_mode': 'timed',
      'settings.sleep_ends_at':
          DateTime.now().subtract(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
      'settings.sleep_minutes': 30,
    });

    final container = ProviderContainer.test();
    // Restore tamamlanana kadar bekle (auto_shuffle varsayılanla farklı).
    final state = await _waitFor(container, (s) => s.autoShuffle);
    expect(state.sleepMode, SleepTimerMode.off);
    expect(state.sleepEndsAt, isNull);
    expect(state.sleepActive, isFalse);
  });

  test('ekolayzır preset seçimi kalıcıdır', () async {
    final first = ProviderContainer.test();
    await first.read(settingsProvider.notifier).setEqualizerPreset('rock');
    expect(first.read(settingsProvider).equalizerPresetId, 'rock');
    expect(first.read(settingsProvider).equalizerPresetLabel, 'Rock');

    final second = ProviderContainer.test();
    final restored =
        await _waitFor(second, (s) => s.equalizerPresetId == 'rock');
    expect(restored.equalizerPresetLabel, 'Rock');
  });

  test('özel bantlar "Özel" presetine dönüşür ve saklanır', () async {
    final first = ProviderContainer.test();
    final notifier = first.read(settingsProvider.notifier);
    await notifier.setEqualizerBands(<double>[0.2, 0.1, 0, -0.1, -0.2]);

    final state = first.read(settingsProvider);
    expect(state.equalizerPresetId, customEqualizerPresetId);
    expect(state.equalizerPresetLabel, 'Özel');
    expect(state.bandsFor(5), <double>[0.2, 0.1, 0, -0.1, -0.2]);

    final second = ProviderContainer.test();
    final restored = await _waitFor(
      second,
      (s) => s.equalizerPresetId == customEqualizerPresetId,
    );
    expect(restored.bandsFor(5)[0], closeTo(0.2, 0.001));
    expect(restored.bandsFor(5)[4], closeTo(-0.2, 0.001));
  });

  test('preset örnekleme bant sayısına uyum sağlar', () {
    expect(equalizerPresetById('flat').sample(5), <double>[0, 0, 0, 0, 0]);
    expect(equalizerPresetById('flat').sample(3), <double>[0, 0, 0]);

    final bass = equalizerPresetById('bass').sample(5);
    expect(bass.first, greaterThan(0.7), reason: 'bas bandı yükseltilmeli');
    expect(bass.last, lessThan(0), reason: 'tiz bandı düşürülmeli');

    final treble = equalizerPresetById('treble').sample(5);
    expect(treble.last, greaterThan(0.7));
    expect(treble.first, lessThan(0));
  });

  test('bandsFor farklı bant sayısına yeniden boyutlandırır', () {
    const state = SettingsState(
      equalizerPresetId: customEqualizerPresetId,
      equalizerBands: <double>[0.1, 0.2, 0.3, 0.4, 0.5],
    );

    expect(state.bandsFor(5), <double>[0.1, 0.2, 0.3, 0.4, 0.5]);

    final resized = state.bandsFor(3);
    expect(resized, hasLength(3));
    expect(resized.first, closeTo(0.1, 0.001));
    expect(resized.last, closeTo(0.5, 0.001));
  });
}
