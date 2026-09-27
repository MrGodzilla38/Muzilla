import 'package:audio_service/audio_service.dart';

/// Sistem kaynaklı oynatma komutlarının (medya bildirimi, Bluetooth kulaklık,
/// Android Auto, kulaklık tuşları) uygulama içindeki oynatıcıya
/// yönlendirildiği arayüz.
abstract class PlaybackController {
  Future<void> resume();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode);

  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode);
}

/// `AudioService.init` tarafından oluşturulan handler.
///
/// Oynatıcı provider'ı henüz hayata geçmemiş olabilir; bu yüzden tüm
/// yönlendirmeler null-safe yapılır.
MuzillaAudioHandler? audioServiceHandler;

class MuzillaAudioHandler extends BaseAudioHandler with SeekHandler {
  PlaybackController? _controller;

  void attach(PlaybackController controller) {
    _controller = controller;
  }

  void detach(PlaybackController controller) {
    if (identical(_controller, controller)) {
      _controller = null;
    }
  }

  @override
  Future<void> play() async {
    await _controller?.resume();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> stop() async {
    await _controller?.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    await _controller?.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _controller?.skipToPrevious();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _controller?.setShuffleMode(shuffleMode);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _controller?.setRepeatMode(repeatMode);
  }

  /// Oynatıcının güncel durumunu medya oturumuna (bildirim + sistem
  /// oynatma kontrolleri) yayınlar.
  ///
  /// Konum yalnızca burada güncellenir; `updateTime` `copyWith` içinde
  /// `DateTime.now()` olarak ayarlandığı için sistem aradaki süreyi kendisi
  /// projekte eder.
  void sync({
    required AudioProcessingState processingState,
    required bool playing,
    required Duration position,
    required MediaItem? item,
    required AudioServiceRepeatMode repeatMode,
    required AudioServiceShuffleMode shuffleMode,
  }) {
    final current = mediaItem.value;
    if (item == null) {
      if (current != null) {
        mediaItem.add(null);
      }
    } else if (current == null ||
        current.id != item.id ||
        current.duration != item.duration) {
      mediaItem.add(item);
    }

    playbackState.add(playbackState.value.copyWith(
      processingState: processingState,
      playing: playing,
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      updatePosition: position,
      repeatMode: repeatMode,
      shuffleMode: shuffleMode,
    ));
  }
}
