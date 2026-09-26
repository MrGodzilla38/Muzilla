import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

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

class PlayerNotifier extends Notifier<SongPlaybackState> {
  static const Duration _positionStep = Duration(milliseconds: 200);

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Duration _lastReportedPosition = Duration.zero;
  int _loadToken = 0;
  bool _streamsReady = false;
  bool _released = false;

  @override
  SongPlaybackState build() {
    ref.onDispose(_release);
    _attachStreams();
    _streamsReady = true;
    return const SongPlaybackState();
  }

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

    final startSong = playlist[index];
    final token = ++_loadToken;
    _lastReportedPosition = Duration.zero;

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
    await _player.seek(target);
    if (!_streamsReady) {
      return;
    }
    _lastReportedPosition = target;
    _writePosition(target);
  }

  Future<void> playNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  Future<void> playPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
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

  void _attachStreams() {
    _subscriptions.addAll([
      _player.playingStream.listen(_writePlaying),
      _player.processingStateStream.listen((processingState) {
        if (processingState != ProcessingState.completed) {
          return;
        }
        _writePlaying(false);
      }),
      _player.positionStream.listen(_handlePosition),
      _player.durationStream.listen((duration) {
        if (!_streamsReady || duration == null || duration == state.duration) {
          return;
        }
        state = state.copyWith(duration: duration);
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
    ]);
  }

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
    if ((position - _lastReportedPosition).abs() < _positionStep) {
      return;
    }
    _lastReportedPosition = position;
    _writePosition(position);
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
  }

  void _release() {
    if (_released) {
      return;
    }
    _released = true;
    _streamsReady = false;
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
