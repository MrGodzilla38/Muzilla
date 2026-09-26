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

  // Filter out very short clips (notification/ringtone noise, etc.)
  final filtered = songs.where((s) => (s.duration ?? 0) > 20000).toList();

  return SongLibraryLoaded(filtered);
});
