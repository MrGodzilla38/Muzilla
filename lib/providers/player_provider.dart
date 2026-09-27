import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../audio/muzilla_audio_handler.dart';
import 'settings_provider.dart';

enum PlayerRepeatMode { off, all, one }

@immutable
class SongPlaybackState {
  const SongPlaybackState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const <SongModel>[],
    this.currentIndex = -1,
    this.shuffleEnabled = false,
    this.repeatMode = PlayerRepeatMode.off,
  });

  final SongModel? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<SongModel> queue;
  final int currentIndex;
  final bool shuffleEnabled;
  final PlayerRepeatMode repeatMode;

  SongPlaybackState copyWith({
    SongModel? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<SongModel>? queue,
    int? currentIndex,
    bool? shuffleEnabled,
    PlayerRepeatMode? repeatMode,
  }) {
    return SongPlaybackState(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, SongPlaybackState>(
  PlayerNotifier.new,
);

class PlayerNotifier extends Notifier<SongPlaybackState>
    implements PlaybackController {
  static const Duration _positionStep = Duration(milliseconds: 200);

  /// Kesintisiz çalma kapalıyken şarkılar arasına giran sessizlik.
  static const Duration _gapDuration = Duration(milliseconds: 1500);

  /// Elle yapılan ileri/geri geçişlerin hemen ardından gelen olayların
  /// "otomatik geçiş" sanılmasını engeller.
  static const Duration _manualTransitionWindow = Duration(milliseconds: 800);

  final AndroidEqualizer _equalizer = AndroidEqualizer();

  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          _equalizer,
      ],
    ),
  );

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Duration _lastReportedPosition = Duration.zero;
  int _loadToken = 0;
  bool _streamsReady = false;
  bool _released = false;

  /// Mevcut şarkının doğal bir geçişle (otomatik ilerleme) başlayıp
  /// başlamadığı; kesintisiz çalma kapalıyken boşluğun uygulanması için.
  bool _gapEligible = false;
  DateTime? _lastManualTransition;

  Timer? _sleepTimer;

  AndroidEqualizerParameters? _equalizerParameters;
  final List<double> _appliedEqualizerGains = <double>[];
  bool? _appliedEqualizerEnabled;

  double _appliedVolume = 1.0;

  @override
  SongPlaybackState build() {
    ref.onDispose(_release);
    ref.onDispose(_detachAudioHandler);
    ref.listen(
      settingsProvider,
      (SettingsState? previous, SettingsState next) =>
          _onSettingsChanged(previous, next),
    );
    audioServiceHandler?.attach(this);
    listenSelf(_onStateChangedForAudio);
    _attachStreams();
    _streamsReady = true;
    // Ayarlar oynatıcıdan önce yüklenmiş olabilir; kalan süreyi planla.
    _syncSleepTimer();
    unawaited(_initEqualizer());
    return const SongPlaybackState();
  }

  /// Ekolayzır bant bilgisi; ilk şarkı yüklenene kadar tamamlanmaz.
  Future<AndroidEqualizerParameters> get equalizerParameters =>
      _equalizer.parameters;

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    final isCurrent =
        state.currentSong?.id == song.id &&
        _player.currentIndex == state.currentIndex;
    if (isCurrent) {
      if (!_player.playing) {
        await _player.play();
      }
      return;
    }

    var playlist = queue ?? const <SongModel>[];
    var index = playlist.indexWhere((item) => item.id == song.id);
    if (index < 0) {
      playlist = <SongModel>[song, ...playlist];
      index = 0;
    }

    final settings = ref.read(settingsProvider);
    if (settings.autoShuffle && !_player.shuffleModeEnabled) {
      await _player.setShuffleModeEnabled(true);
    }

    final startSong = playlist[index];
    final token = ++_loadToken;
    _lastReportedPosition = Duration.zero;
    _markManualTransition();
    _gapEligible = false;

    state = SongPlaybackState(
      currentSong: startSong,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration(milliseconds: startSong.duration ?? 0),
      queue: playlist,
      currentIndex: index,
      shuffleEnabled: _player.shuffleModeEnabled,
      repeatMode: _repeatModeOf(_player.loopMode),
    );
    _applyVolumeEnvelope();

    try {
      await _player.setAudioSources(
        [for (final item in playlist) _sourceFor(item)],
        initialIndex: index,
        initialPosition: Duration.zero,
      );
      await _player.play();
    } catch (error) {
      if (token != _loadToken || !ref.mounted) {
        return;
      }
      debugPrint('Muzilla: playback failed for "${song.title}": $error');
      state = SongPlaybackState(
        shuffleEnabled: _player.shuffleModeEnabled,
        repeatMode: _repeatModeOf(_player.loopMode),
      );
      _applyVolumeEnvelope();
    }
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong == null) {
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      _writePlaying(true);
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Çalan (varsa) oynatmayı duraklatır; uyku zamanlayıcısı için.
  Future<void> pausePlayback() async {
    if (_player.playing) {
      await _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (state.currentSong == null) {
      return;
    }
    var target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    final total = state.duration;
    if (total > Duration.zero && target > total) {
      target = total;
    }
    _markManualTransition();
    await _player.seek(target);
    if (!_streamsReady) {
      return;
    }
    _lastReportedPosition = target;
    _writePosition(target);
    _applyVolumeEnvelope();
    _broadcastAudio(state);
  }

  Future<void> playNext() async {
    if (_player.hasNext) {
      _markManualTransition();
      await _player.seekToNext();
    }
  }

  Future<void> playPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      _markManualTransition();
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      _markManualTransition();
      await _player.seekToPrevious();
    } else {
      _markManualTransition();
      await _player.seek(Duration.zero);
    }
  }

  Future<void> toggleShuffle() async {
    await _player.setShuffleModeEnabled(!state.shuffleEnabled);
  }

  Future<void> cycleRepeat() async {
    final LoopMode next = switch (state.repeatMode) {
      PlayerRepeatMode.off => LoopMode.all,
      PlayerRepeatMode.all => LoopMode.one,
      PlayerRepeatMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
  }

  // ---------------------------------------------------------------------------
  // Sistem kontrolleri (medya bildirimi, Bluetooth kulaklık, medya tuşları)
  // ---------------------------------------------------------------------------

  @override
  Future<void> resume() async {
    if (state.currentSong == null) {
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    if (!_player.playing) {
      await _player.play();
    }
  }

  @override
  Future<void> pause() => pausePlayback();

  @override
  Future<void> stop() => pausePlayback();

  @override
  Future<void> skipToNext() => playNext();

  @override
  Future<void> skipToPrevious() => playPrevious();

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) {
    return _setShuffleEnabled(shuffleMode != AudioServiceShuffleMode.none);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final LoopMode mode = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => LoopMode.all,
    };
    if (mode == _player.loopMode) {
      return;
    }
    try {
      await _player.setLoopMode(mode);
    } catch (error) {
      debugPrint('Muzilla: tekrar modu değiştirilemedi: $error');
    }
  }

  /// Sistem medya oturumundaki durumu oynatıcının durumuyla eşitler.
  void _broadcastAudio(SongPlaybackState snapshot) {
    final handler = audioServiceHandler;
    if (handler == null || _released || !_streamsReady) {
      return;
    }
    handler.sync(
      processingState: _audioProcessingState(),
      playing: snapshot.isPlaying,
      position: snapshot.position,
      item: _mediaItemFor(snapshot),
      repeatMode: _audioRepeatMode(snapshot.repeatMode),
      shuffleMode: snapshot.shuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  void _onStateChangedForAudio(
    SongPlaybackState? previous,
    SongPlaybackState next,
  ) {
    if (!_shouldBroadcastAudio(previous, next)) {
      return;
    }
    _broadcastAudio(next);
  }

  /// Konum, sistem tarafında `updateTime` kullanılarak projekte edildiği için
  /// saniyede birkaç kez tekrarlanan yayınlar gereksizdir.
  bool _shouldBroadcastAudio(
    SongPlaybackState? previous,
    SongPlaybackState next,
  ) {
    if (previous == null) {
      return true;
    }
    if (previous.isPlaying != next.isPlaying ||
        previous.currentSong?.id != next.currentSong?.id ||
        previous.currentIndex != next.currentIndex ||
        previous.duration != next.duration ||
        previous.shuffleEnabled != next.shuffleEnabled ||
        previous.repeatMode != next.repeatMode) {
      return true;
    }
    return previous.position != next.position && !next.isPlaying;
  }

  void _detachAudioHandler() {
    audioServiceHandler?.detach(this);
  }

  MediaItem? _mediaItemFor(SongPlaybackState snapshot) {
    final song = snapshot.currentSong;
    if (song == null) {
      return null;
    }
    final durationMs = snapshot.duration > Duration.zero
        ? snapshot.duration.inMilliseconds
        : (song.duration ?? 0);
    return MediaItem(
      id: song.id.toString(),
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      artUri: Uri.parse(
        'content://media/external/audio/media/${song.id}/albumart',
      ),
    );
  }

  AudioProcessingState _audioProcessingState() {
    return switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  AudioServiceRepeatMode _audioRepeatMode(PlayerRepeatMode mode) {
    return switch (mode) {
      PlayerRepeatMode.off => AudioServiceRepeatMode.none,
      PlayerRepeatMode.all => AudioServiceRepeatMode.all,
      PlayerRepeatMode.one => AudioServiceRepeatMode.one,
    };
  }

  void _attachStreams() {
    _subscriptions.addAll([
      _player.playingStream.listen(_writePlaying),
      _player.processingStateStream.listen((processingState) {
        if (!_streamsReady) {
          return;
        }
        if (processingState == ProcessingState.completed) {
          _writePlaying(false);
        }
        _broadcastAudio(state);
      }),
      _player.positionStream.listen(_handlePosition),
      _player.durationStream.listen((duration) {
        if (!_streamsReady || duration == null || duration == state.duration) {
          return;
        }
        state = state.copyWith(duration: duration);
        _applyVolumeEnvelope();
      }),
      _player.currentIndexStream.listen(_handleIndex),
      _player.shuffleModeEnabledStream.listen((enabled) {
        if (!_streamsReady || state.shuffleEnabled == enabled) {
          return;
        }
        state = state.copyWith(shuffleEnabled: enabled);
      }),
      _player.loopModeStream.listen((mode) {
        if (!_streamsReady) {
          return;
        }
        final repeatMode = _repeatModeOf(mode);
        if (state.repeatMode == repeatMode) {
          return;
        }
        state = state.copyWith(repeatMode: repeatMode);
      }),
      _player.positionDiscontinuityStream.listen(_handleDiscontinuity),
    ]);
  }

  /// Oynatma sırasındaki değişimleri ayıklar:
  /// - `autoAdvance`: şarkı kendi kendine bitti -> boşluk + "şarkı sonunda"
  ///   uyku modu devreye girer.
  /// - `seek`: kullanıcı elledi -> boşluk uygulanmaz.
  void _handleDiscontinuity(PositionDiscontinuity discontinuity) {
    if (!_streamsReady) {
      return;
    }
    if (discontinuity.reason == PositionDiscontinuityReason.seek) {
      _gapEligible = false;
      return;
    }
    if (_wasManuallyTriggered()) {
      _gapEligible = false;
      return;
    }
    _gapEligible = true;
    _handleNaturalSongEnd();
  }

  void _handleNaturalSongEnd() {
    if (!ref.mounted) {
      return;
    }
    if (ref.read(settingsProvider).sleepMode != SleepTimerMode.songEnd) {
      return;
    }
    unawaited(pausePlayback());
    unawaited(ref.read(settingsProvider.notifier).clearSleepTimer());
  }

  void _markManualTransition() {
    _lastManualTransition = DateTime.now();
    _gapEligible = false;
  }

  bool _wasManuallyTriggered() {
    final last = _lastManualTransition;
    if (last == null) {
      return false;
    }
    if (DateTime.now().difference(last) > _manualTransitionWindow) {
      _lastManualTransition = null;
      return false;
    }
    return true;
  }

  void _onSettingsChanged(SettingsState? previous, SettingsState next) {
    if (previous == null) {
      return;
    }
    if (next.autoShuffle != previous.autoShuffle && state.queue.isNotEmpty) {
      unawaited(_setShuffleEnabled(next.autoShuffle));
    }
    if (next.gapless != previous.gapless ||
        next.crossfade != previous.crossfade ||
        next.crossfadeSeconds != previous.crossfadeSeconds) {
      _applyVolumeEnvelope();
    }
    if (next.sleepEndsAt != previous.sleepEndsAt ||
        next.sleepMode != previous.sleepMode) {
      _syncSleepTimer();
    }
    if (next.equalizerPresetId != previous.equalizerPresetId ||
        !listEquals(next.equalizerBands, previous.equalizerBands)) {
      unawaited(_applyEqualizer());
    }
  }

  Future<void> _setShuffleEnabled(bool enabled) async {
    if (state.shuffleEnabled == enabled) {
      return;
    }
    try {
      await _player.setShuffleModeEnabled(enabled);
    } catch (error) {
      debugPrint('Muzilla: karıştırma değiştirilemedi: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Ses zarfı: kesintisiz çalma boşluğu + geçiş efektleri (solumalar)
  // ---------------------------------------------------------------------------

  void _applyVolumeEnvelope() {
    if (!_streamsReady) {
      return;
    }
    final settings = ref.read(settingsProvider);
    final position = state.position;
    final duration = state.duration;

    var volume = 1.0;
    final gapActive =
        !settings.gapless && _gapEligible && position < _gapDuration;
    if (gapActive) {
      volume = 0.0;
    }

    if (settings.crossfade && duration > Duration.zero) {
      final fadeMs = (settings.crossfadeSeconds * 1000).round();
      final audiblePosition =
          position - (gapActive ? _gapDuration : Duration.zero);
      var fadeIn = 1.0;
      if (audiblePosition.inMilliseconds < fadeMs) {
        fadeIn = audiblePosition <= Duration.zero
            ? 0.0
            : audiblePosition.inMilliseconds / fadeMs;
      }
      final remaining = duration - position;
      var fadeOut = 1.0;
      if (remaining.inMilliseconds < fadeMs) {
        fadeOut = remaining <= Duration.zero
            ? 0.0
            : remaining.inMilliseconds / fadeMs;
      }
      volume *= math.min(fadeIn, fadeOut);
    }

    if (volume < 0.0) {
      volume = 0.0;
    } else if (volume > 1.0) {
      volume = 1.0;
    }
    if (volume == _appliedVolume) {
      return;
    }
    _appliedVolume = volume;
    unawaited(_player.setVolume(volume));
  }

  // ---------------------------------------------------------------------------
  // Ekolayzır
  // ---------------------------------------------------------------------------

  Future<void> _initEqualizer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      // Platforma ilk bağlanışta (ilk şarkı yüklenirken) tamamlanır.
      final parameters = await _equalizer.parameters;
      if (_released || !ref.mounted) {
        return;
      }
      _equalizerParameters = parameters;
      await _applyEqualizer();
    } catch (error) {
      debugPrint('Muzilla: ekolayzır bilgisi alınamadı: $error');
    }
  }

  Future<void> _applyEqualizer() async {
    final parameters = _equalizerParameters;
    if (parameters == null || _released) {
      return;
    }
    try {
      final settings = ref.read(settingsProvider);
      final bands = settings.bandsFor(parameters.bands.length);
      for (var i = 0; i < parameters.bands.length; i++) {
        final normalized = i < bands.length ? bands[i] : 0.0;
        var gain = normalized >= 0
            ? normalized * parameters.maxDecibels
            : normalized * parameters.minDecibels.abs();
        if (gain < parameters.minDecibels) {
          gain = parameters.minDecibels;
        } else if (gain > parameters.maxDecibels) {
          gain = parameters.maxDecibels;
        }
        if (i < _appliedEqualizerGains.length &&
            (_appliedEqualizerGains[i] - gain).abs() < 0.01) {
          continue;
        }
        while (_appliedEqualizerGains.length <= i) {
          _appliedEqualizerGains.add(0.0);
        }
        _appliedEqualizerGains[i] = gain;
        await parameters.bands[i].setGain(gain);
      }
      final enabled = settings.equalizerPresetId != equalizerPresets.first.id ||
          bands.any((band) => band.abs() > 0.001);
      if (_appliedEqualizerEnabled != enabled) {
        _appliedEqualizerEnabled = enabled;
        await _equalizer.setEnabled(enabled);
      }
    } catch (error) {
      debugPrint('Muzilla: ekolayzır uygulanamadı: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Uyku zamanlayıcı
  // ---------------------------------------------------------------------------

  void _syncSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (!ref.mounted) {
      return;
    }
    final settings = ref.read(settingsProvider);
    if (settings.sleepMode != SleepTimerMode.timed) {
      return;
    }
    final endsAt = settings.sleepEndsAt;
    if (endsAt == null) {
      return;
    }
    final remaining = endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _expireSleepTimer();
      return;
    }
    _sleepTimer = Timer(remaining, _expireSleepTimer);
  }

  void _expireSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    unawaited(pausePlayback());
    if (ref.mounted) {
      unawaited(ref.read(settingsProvider.notifier).clearSleepTimer());
    }
  }

  bool _sleepTimerExpiredNow() {
    if (!ref.mounted) {
      return false;
    }
    final settings = ref.read(settingsProvider);
    final endsAt = settings.sleepEndsAt;
    if (settings.sleepMode != SleepTimerMode.timed || endsAt == null) {
      return false;
    }
    if (DateTime.now().isBefore(endsAt)) {
      return false;
    }
    _expireSleepTimer();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Durum yazma yardımcıları
  // ---------------------------------------------------------------------------

  void _writePlaying(bool playing) {
    if (!_streamsReady || state.isPlaying == playing) {
      return;
    }
    state = state.copyWith(isPlaying: playing);
  }

  void _writePosition(Duration position) {
    if (!_streamsReady || state.position == position) {
      return;
    }
    state = state.copyWith(position: position);
  }

  void _handlePosition(Duration position) {
    if (!_streamsReady || position == state.position) {
      return;
    }
    if (_sleepTimerExpiredNow()) {
      return;
    }
    if ((position - _lastReportedPosition).abs() < _positionStep) {
      return;
    }
    _lastReportedPosition = position;
    _writePosition(position);
    _applyVolumeEnvelope();
  }

  void _handleIndex(int? index) {
    if (!_streamsReady || index == null || index == state.currentIndex) {
      return;
    }
    final queue = state.queue;
    if (index < 0 || index >= queue.length) {
      return;
    }
    final song = queue[index];
    _lastReportedPosition = Duration.zero;
    state = state.copyWith(
      currentSong: song,
      currentIndex: index,
      position: Duration.zero,
      duration: Duration(milliseconds: song.duration ?? 0),
    );
    _applyVolumeEnvelope();
  }

  void _release() {
    if (_released) {
      return;
    }
    _released = true;
    _streamsReady = false;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player.dispose();
  }

  AudioSource _sourceFor(SongModel song) {
    final uri = song.uri;
    if (uri != null && uri.isNotEmpty) {
      return AudioSource.uri(Uri.parse(uri));
    }
    return AudioSource.file(song.data);
  }

  PlayerRepeatMode _repeatModeOf(LoopMode mode) {
    return switch (mode) {
      LoopMode.off => PlayerRepeatMode.off,
      LoopMode.all => PlayerRepeatMode.all,
      LoopMode.one => PlayerRepeatMode.one,
    };
  }
}
