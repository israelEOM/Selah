/// Seconds as HH:MM:SS.
String clock(num? seconds) {
  if (seconds == null) return '--:--:--';
  final total = seconds.floor();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(total ~/ 3600)}:${two(total % 3600 ~/ 60)}:${two(total % 60)}';
}

/// Parses HH:MM:SS, MM:SS or plain seconds. Returns null when the text is not a time.
int? parseClock(String text) {
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  var total = 0;
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0) return null;
    total = total * 60 + value;
  }
  return total;
}

Uri youtubeAt(String videoId, num? seconds) => Uri.parse(
    'https://www.youtube.com/watch?v=$videoId${seconds == null ? '' : '&t=${seconds.floor()}s'}');
