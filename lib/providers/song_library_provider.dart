import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

final _audioQuery = OnAudioQuery();

/// Result of trying to load the device's song library.
/// We model permission-denied as a distinct case so the UI can show a
/// clear "izin ver" screen instead of a generic error.
sealed class SongLibraryResult {
  const SongLibraryResult();
}

class SongLibraryLoaded extends SongLibraryResult {
  final List<SongModel> songs;
  const SongLibraryLoaded(this.songs);
}

class SongLibraryPermissionDenied extends SongLibraryResult {
  const SongLibraryPermissionDenied();
}

/// Only files living under the device's public Music folder count as music.
/// Voice notes, WhatsApp audios, recordings, ringtones etc. live in other
/// directories (Recordings, WhatsApp/, Notifications, ...) even when
/// MediaStore reports them as audio.
bool isInMusicFolder(String path) {
  final segments = path.replaceAll('\\', '/').split('/')..removeWhere((s) => s.isEmpty);
  return segments.any((s) {
    final name = s.toLowerCase();
    return name == 'music' || name == 'müzik';
  });
}

final songLibraryProvider = FutureProvider<SongLibraryResult>((ref) async {
  final alreadyGranted = await _audioQuery.permissionsStatus();
  final granted = alreadyGranted || await _audioQuery.permissionsRequest();

  if (!granted) {
    return const SongLibraryPermissionDenied();
  }

  final songs = await _audioQuery.querySongs(
    sortType: SongSortType.TITLE,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
    ignoreCase: true,
  );

  // Keep only real music: files inside the Music folder and long enough to
  // be songs (drops notification/ringtone noise).
  final filtered = songs
      .where((s) => isInMusicFolder(s.data) && (s.duration ?? 0) > 20000)
      .toList();

  return SongLibraryLoaded(filtered);
});
