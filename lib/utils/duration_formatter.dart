/// Formats a duration given in milliseconds (as [on_audio_query] provides)
/// into an "mm:ss" string, e.g. 03:42.
String formatDurationMs(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return '--:--';
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final secondsStr = seconds.toString().padLeft(2, '0');
  return '$minutes:$secondsStr';
}
