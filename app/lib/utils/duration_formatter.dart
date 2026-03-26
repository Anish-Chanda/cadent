/// Formats a duration given in seconds as H:MM:SS or M:SS.
/// Use for precise displays that need second-level granularity.
String formatDuration(double seconds) {
  final d = Duration(seconds: seconds.round());
  if (d.inHours > 0) {
    return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
