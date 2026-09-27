import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uyku zamanlayıcının çalışma şekli.
enum SleepTimerMode {
  /// Kapalı.
  off,

  /// Belirli bir süre sonra duraklat.
  timed,

  /// Çalan şarkı bitince duraklat.
  songEnd,
}

/// Kullanıcının kaydırıcılarla oluşturduğu özel preset kimliği.
const String customEqualizerPresetId = 'custom';

/// Ekolayzır preset'i: `anchors`, bas->tiz yönünde normalize (-1..1) kazanç
/// hedefleridir. Cihazın bant sayısı farklı olsa da preset bu hedeflerden
/// örneklendirilerek uygulanır.
@immutable
class EqualizerPreset {
  const EqualizerPreset({
    required this.id,
    required this.label,
    required this.anchors,
  });

  final String id;
  final String label;
  final List<double> anchors;

  /// Preset'i verilen bant sayısına örneklendirir.
  List<double> sample(int bandCount) {
    if (bandCount <= 0) {
      return const <double>[];
    }
    if (anchors.isEmpty) {
      return List<double>.filled(bandCount, 0, growable: false);
    }
    return List<double>.generate(bandCount, (i) {
      final t = bandCount == 1 ? 0.5 : (i + 0.5) / bandCount;
      return _sampleAnchors(anchors, t);
    }, growable: false);
  }
}

double _sampleAnchors(List<double> anchors, double t) {
  if (anchors.length == 1) {
    return anchors.first;
  }
  final x = t.clamp(0.0, 1.0) * (anchors.length - 1);
  final index = x.floor();
  if (index >= anchors.length - 1) {
    return anchors.last;
  }
  final fraction = x - index;
  return anchors[index] * (1 - fraction) + anchors[index + 1] * fraction;
}

const List<EqualizerPreset> equalizerPresets = <EqualizerPreset>[
  EqualizerPreset(id: 'flat', label: 'Dengeli', anchors: [0, 0, 0, 0, 0]),
  EqualizerPreset(id: 'bass', label: 'Bas', anchors: [1, 0.55, 0.05, -0.1, -0.15]),
  EqualizerPreset(id: 'treble', label: 'Tiz', anchors: [-0.15, -0.1, 0.1, 0.55, 1]),
  EqualizerPreset(id: 'pop', label: 'Pop', anchors: [-0.2, 0.25, 0.5, 0.3, 0]),
  EqualizerPreset(id: 'rock', label: 'Rock', anchors: [0.5, 0.2, -0.1, 0.3, 0.55]),
  EqualizerPreset(id: 'jazz', label: 'Caz', anchors: [0.25, 0, 0.15, 0.35, 0.5]),
  EqualizerPreset(id: 'dance', label: 'Dans', anchors: [0.6, 0.3, 0, 0.25, 0.45]),
  EqualizerPreset(id: 'electronic', label: 'Elektronik', anchors: [0.7, 0.35, -0.25, 0.2, 0.6]),
  EqualizerPreset(id: 'vocal', label: 'Vokal', anchors: [-0.35, -0.05, 0.55, 0.45, 0.1]),
];

EqualizerPreset equalizerPresetById(String id) {
  for (final preset in equalizerPresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return equalizerPresets.first;
}

List<double> _resizeBands(List<double> source, int bandCount) {
  if (bandCount <= 0) {
    return const <double>[];
  }
  if (source.isEmpty) {
    return List<double>.filled(bandCount, 0, growable: false);
  }
  if (source.length == bandCount) {
    return List<double>.from(source, growable: false);
  }
  if (bandCount == 1) {
    return <double>[source.first];
  }
  return List<double>.generate(bandCount, (i) {
    final x = i * (source.length - 1) / (bandCount - 1);
    final low = x.floor();
    final high = x.ceil();
    if (low == high) {
      return source[low];
    }
    final fraction = x - low;
    return source[low] * (1 - fraction) + source[high] * fraction;
  }, growable: false);
}

@immutable
class SettingsState {
  const SettingsState({
    this.autoShuffle = false,
    this.gapless = true,
    this.crossfade = true,
    this.sleepMode = SleepTimerMode.off,
    this.sleepEndsAt,
    this.sleepRemaining = Duration.zero,
    this.sleepMinutes,
    this.equalizerPresetId = 'flat',
    this.equalizerBands = const <double>[0, 0, 0, 0, 0],
  });

  /// Sıradaki çalma listesi başlarken karıştırma otomatik açılsın.
  final bool autoShuffle;

  /// Kapalıyken şarkılar arasına kısa bir sessizlik girer.
  final bool gapless;

  /// Şarkı geçişlerinde açılış/kapanış solması.
  final bool crossfade;

  final SleepTimerMode sleepMode;

  /// [SleepTimerMode.timed] için bitiş anı.
  final DateTime? sleepEndsAt;

  /// Geri sayım (yalnızca gösterim amaçlı, saniyelik güncellenir).
  final Duration sleepRemaining;

  /// Kullanıcının seçtiği toplam dakika (radio göstergesi için).
  final int? sleepMinutes;

  final String equalizerPresetId;

  /// Yalnızca [customEqualizerPresetId] sırasında saklanan bantlar (-1..1).
  final List<double> equalizerBands;

  static const Object _unset = Object();

  SettingsState copyWith({
    bool? autoShuffle,
    bool? gapless,
    bool? crossfade,
    SleepTimerMode? sleepMode,
    Object? sleepEndsAt = _unset,
    Duration? sleepRemaining,
    int? sleepMinutes,
    String? equalizerPresetId,
    List<double>? equalizerBands,
  }) {
    return SettingsState(
      autoShuffle: autoShuffle ?? this.autoShuffle,
      gapless: gapless ?? this.gapless,
      crossfade: crossfade ?? this.crossfade,
      sleepMode: sleepMode ?? this.sleepMode,
      sleepEndsAt: identical(sleepEndsAt, _unset)
          ? this.sleepEndsAt
          : sleepEndsAt as DateTime?,
      sleepRemaining: sleepRemaining ?? this.sleepRemaining,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      equalizerPresetId: equalizerPresetId ?? this.equalizerPresetId,
      equalizerBands: equalizerBands ?? this.equalizerBands,
    );
  }

  bool get sleepActive => sleepMode != SleepTimerMode.off;

  String get equalizerPresetLabel => equalizerPresetId == customEqualizerPresetId
      ? 'Özel'
      : equalizerPresetById(equalizerPresetId).label;

  /// Aktif preset'in (veya özel bantların) verilen bant sayısına göre hali.
  List<double> bandsFor(int bandCount) {
    if (bandCount <= 0) {
      return const <double>[];
    }
    final source = equalizerPresetId == customEqualizerPresetId
        ? equalizerBands
        : equalizerPresetById(equalizerPresetId).sample(bandCount);
    return _resizeBands(source, bandCount);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _keyAutoShuffle = 'settings.auto_shuffle';
  static const String _keyGapless = 'settings.gapless';
  static const String _keyCrossfade = 'settings.crossfade';
  static const String _keySleepMode = 'settings.sleep_mode';
  static const String _keySleepEndsAt = 'settings.sleep_ends_at';
  static const String _keySleepMinutes = 'settings.sleep_minutes';
  static const String _keyEqualizerPreset = 'settings.equalizer_preset';
  static const String _keyEqualizerBands = 'settings.equalizer_bands';

  SharedPreferences? _prefs;
  Timer? _sleepTicker;
  Future<void>? _restoreFuture;

  @override
  SettingsState build() {
    ref.onDispose(_stopSleepTicker);
    _restoreFuture = _restore();
    return const SettingsState();
  }

  /// İlk yükleme bitmeden yazma yapılmaz; yoksa restore eski değerlerle
  /// taze ayarların üzerine yazabilir.
  Future<void> _ensureRestored() async {
    final future = _restoreFuture;
    if (future != null) {
      await future;
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) {
        return;
      }
      _prefs = prefs;

      var sleepMode = SleepTimerMode.off;
      DateTime? sleepEndsAt;
      var sleepRemaining = Duration.zero;

      final modeName = prefs.getString(_keySleepMode);
      if (modeName == SleepTimerMode.songEnd.name) {
        sleepMode = SleepTimerMode.songEnd;
      } else if (modeName == SleepTimerMode.timed.name) {
        final endsAtMs = prefs.getInt(_keySleepEndsAt) ?? 0;
        if (endsAtMs > 0) {
          final endsAt = DateTime.fromMillisecondsSinceEpoch(endsAtMs);
          final remaining = endsAt.difference(DateTime.now());
          if (remaining > Duration.zero) {
            sleepMode = SleepTimerMode.timed;
            sleepEndsAt = endsAt;
            sleepRemaining = remaining;
          }
        }
      }

      state = SettingsState(
        autoShuffle: prefs.getBool(_keyAutoShuffle) ?? false,
        gapless: prefs.getBool(_keyGapless) ?? true,
        crossfade: prefs.getBool(_keyCrossfade) ?? true,
        sleepMode: sleepMode,
        sleepEndsAt: sleepEndsAt,
        sleepRemaining: sleepRemaining,
        sleepMinutes: prefs.getInt(_keySleepMinutes),
        equalizerPresetId:
            prefs.getString(_keyEqualizerPreset) ?? equalizerPresets.first.id,
        equalizerBands: _readBands(prefs.getStringList(_keyEqualizerBands)),
      );

      if (state.sleepMode == SleepTimerMode.timed) {
        _startSleepTicker();
      }
    } catch (error) {
      debugPrint('Muzilla: ayarlar okunamadı: $error');
    }
  }

  List<double> _readBands(List<String>? raw) {
    if (raw == null || raw.isEmpty) {
      return const <double>[0, 0, 0, 0, 0];
    }
    return raw.map(double.parse).toList(growable: false);
  }

  Future<void> setAutoShuffle(bool value) async {
    await _ensureRestored();
    state = state.copyWith(autoShuffle: value);
    await _prefs?.setBool(_keyAutoShuffle, value);
  }

  Future<void> setGapless(bool value) async {
    await _ensureRestored();
    state = state.copyWith(gapless: value);
    await _prefs?.setBool(_keyGapless, value);
  }

  Future<void> setCrossfade(bool value) async {
    await _ensureRestored();
    state = state.copyWith(crossfade: value);
    await _prefs?.setBool(_keyCrossfade, value);
  }

  /// Süreli uyku zamanlayıcıyı başlatır.
  Future<void> setSleepTimerDuration(int minutes) async {
    await _ensureRestored();
    final endsAt = DateTime.now().add(Duration(minutes: minutes));
    state = state.copyWith(
      sleepMode: SleepTimerMode.timed,
      sleepEndsAt: endsAt,
      sleepRemaining: Duration(minutes: minutes),
      sleepMinutes: minutes,
    );
    _startSleepTicker();
    await _prefs?.setString(_keySleepMode, SleepTimerMode.timed.name);
    await _prefs?.setInt(_keySleepEndsAt, endsAt.millisecondsSinceEpoch);
    await _prefs?.setInt(_keySleepMinutes, minutes);
  }

  /// Şarkı sonunda duraklat modunu açar.
  Future<void> setSleepTimerOnSongEnd() async {
    await _ensureRestored();
    state = state.copyWith(
      sleepMode: SleepTimerMode.songEnd,
      sleepEndsAt: null,
      sleepRemaining: Duration.zero,
      sleepMinutes: null,
    );
    _stopSleepTicker();
    await _prefs?.setString(_keySleepMode, SleepTimerMode.songEnd.name);
    await _prefs?.remove(_keySleepEndsAt);
    await _prefs?.remove(_keySleepMinutes);
  }

  Future<void> clearSleepTimer() async {
    await _ensureRestored();
    _stopSleepTicker();
    state = state.copyWith(
      sleepMode: SleepTimerMode.off,
      sleepEndsAt: null,
      sleepRemaining: Duration.zero,
      sleepMinutes: null,
    );
    await _prefs?.setString(_keySleepMode, SleepTimerMode.off.name);
    await _prefs?.remove(_keySleepEndsAt);
    await _prefs?.remove(_keySleepMinutes);
  }

  void _startSleepTicker() {
    _sleepTicker?.cancel();
    _sleepTicker =
        Timer.periodic(const Duration(seconds: 1), (_) => _onSleepTick());
  }

  void _stopSleepTicker() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
  }

  void _onSleepTick() {
    final endsAt = state.sleepEndsAt;
    if (state.sleepMode != SleepTimerMode.timed || endsAt == null) {
      _stopSleepTicker();
      return;
    }
    // Sıfırlandığında modu burada kapatmayız; oynatmayı duraklatan taraf
    // (player) süre dolduğunda clearSleepTimer çağırır.
    final remaining = endsAt.difference(DateTime.now());
    state = state.copyWith(
      sleepRemaining: remaining > Duration.zero ? remaining : Duration.zero,
    );
  }

  Future<void> setEqualizerPreset(String id) async {
    await _ensureRestored();
    state = state.copyWith(equalizerPresetId: id);
    await _prefs?.setString(_keyEqualizerPreset, id);
  }

  /// Kaydırıcılardan gelen tam bant setini "Özel" preset olarak kaydeder.
  Future<void> setEqualizerBands(List<double> bands) async {
    await _ensureRestored();
    final normalized = List<double>.unmodifiable(bands);
    state = state.copyWith(
      equalizerPresetId: customEqualizerPresetId,
      equalizerBands: normalized,
    );
    await _prefs?.setString(_keyEqualizerPreset, customEqualizerPresetId);
    await _prefs?.setStringList(
      _keyEqualizerBands,
      [for (final band in normalized) band.toStringAsFixed(3)],
    );
  }
}
