/// Línea individual de letra sincronizada en formato LRC.
class LrcLine {
  final Duration timestamp;
  final String text;

  const LrcLine({required this.timestamp, required this.text});
}

/// Parser liviano de letras sincronizadas LRC (`[mm:ss.xx] texto` o `[mm:ss] texto`).
class LrcParser {
  static final RegExp _lineRegex = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)',
  );

  static List<LrcLine> parse(String? rawLrc) {
    if (rawLrc == null || rawLrc.trim().isEmpty) {
      return const [];
    }

    final result = <LrcLine>[];
    for (final rawLine in rawLrc.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final matches = _lineRegex.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      final lastMatch = matches.last;
      final lyricText = (lastMatch.group(4) ?? '').trim();
      if (lyricText.isEmpty) continue;

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fracStr = match.group(3);
        var millis = 0;
        if (fracStr != null && fracStr.isNotEmpty) {
          if (fracStr.length == 1) {
            millis = int.parse(fracStr) * 100;
          } else if (fracStr.length == 2) {
            millis = int.parse(fracStr) * 10;
          } else {
            millis = int.parse(fracStr.substring(0, 3));
          }
        }
        result.add(
          LrcLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: lyricText,
          ),
        );
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  /// Devuelve el índice de la línea activa para la [position] actual, o `-1`
  /// si todavía no empezó ninguna línea.
  static int activeLineIndex(List<LrcLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}
