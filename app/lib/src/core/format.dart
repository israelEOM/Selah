import 'bible_books.dart';

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

/// YouVersion's id and short name for each version in `bible_versions`.
const _youVersion = {
  'RVR1960': (149, 'RVR1960'),
  'NVI': (128, 'NVI'),
  'ARA': (1608, 'ARA'),
  'NVI-PT': (129, 'NVI'),
  'KJV': (1, 'KJV'),
  'NIV': (111, 'NIV'),
  'ESV': (59, 'ESV'),
};

final _reference = RegExp(r'^(.+?)\s+(\d{1,3})(?::(\d{1,3})(?:\s*[-–—]\s*(\d{1,3}))?)?$');

String _fold(String text) => text.toLowerCase().replaceAllMapped(
    RegExp('[áàâãäéèêëíìîïóòôõöúùûüç]'), (m) => 'aaaaaeeeeiiiiooooouuuuc'['áàâãäéèêëíìîïóòôõöúùûüç'.indexOf(m[0]!)]);

/// Selah never stores Bible text; readings open in an external reader.
/// bible.com links open the YouVersion app when it is installed, the website otherwise.
/// A reference or version YouVersion can't be matched to falls back to Bible Gateway.
Uri bibleReaderUrl(String reference, String versionCode) {
  final version = _youVersion[versionCode];
  final match = _reference.firstMatch(reference.trim());
  final book = match == null ? null : bookCodes[_fold(match[1]!)];
  if (version == null || book == null) {
    return Uri.https('www.biblegateway.com', '/passage/', {'search': reference, 'version': versionCode});
  }
  final verses = match![3] == null ? '' : '.${match[3]}${match[4] == null ? '' : '-${match[4]}'}';
  return Uri.https('www.bible.com', '/bible/${version.$1}/$book.${match[2]}$verses.${version.$2}');
}
