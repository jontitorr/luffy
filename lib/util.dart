import "dart:async";
import "dart:convert";
import "dart:math";

import "package:color_log/color_log.dart";
import "package:flutter/foundation.dart";

dynamic tryJsonDecode(String? s) {
  if (s == null) {
    return null;
  }

  try {
    return jsonDecode(s);
  } catch (e) {
    return null;
  }
}

Future<String> readResponse(HttpClientResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.transform(utf8.decoder).listen(
    (data) {
      contents.write(data);
    },
    onDone: () => completer.complete(contents.toString()),
  );
  return completer.future;
}

void prints(
  s1, {
  LogLevel level = LogLevel.debug,
}) {
  if (level == LogLevel.debug && !kDebugMode) {
    return;
  }

  final s = s1.toString();
  final pattern = RegExp(".{1,800}");

  pattern.allMatches(s).forEach((match) {
    final m = match.group(0);

    if (m != null) {
      if (level == LogLevel.info) {
        clog.info(m);
      } else if (level == LogLevel.warning) {
        clog.warning(m);
      } else if (level == LogLevel.error) {
        clog.error(m);
      } else if (level == LogLevel.debug) {
        clog.debug(m);
      }
    }
  });
}

int get unixTime => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _substringAfterImpl(String source, String pattern) {
  final index = source.indexOf(pattern);
  return index >= 0 ? source.substring(index + pattern.length) : "";
}

String _substringBeforeImpl(String source, String pattern) {
  final index = source.indexOf(pattern);
  return index >= 0 ? source.substring(0, index) : source;
}

String _substringBeforeLastImpl(String source, String pattern) {
  final index = source.lastIndexOf(pattern);
  return index >= 0 ? source.substring(0, index) : source;
}

String _unescapedJsonStringImpl(String escapedString) {
  return jsonDecode('"$escapedString"');
}

String _substringAfterLastImpl(String source, String pattern) {
  final index = source.lastIndexOf(pattern);
  if (index >= 0 && index < source.length - 1) {
    return source.substring(index + pattern.length);
  }
  return "";
}

// Function which formats bytes into a human readable format.
String formatBytes(int bytes, int decimals) {
  if (bytes <= 0) {
    return "0 B";
  }

  const k = 1024;
  final dm = decimals < 0 ? 0 : decimals;
  const sizes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

  final i = (log(bytes) / log(k)).floor();

  return "${(bytes / pow(k, i)).toStringAsFixed(dm)} ${sizes[i]}";
}

extension StringExtensions on String {
  String substringAfter(String pattern) {
    return _substringAfterImpl(this, pattern);
  }

  String substringBefore(String pattern) {
    return _substringBeforeImpl(this, pattern);
  }

  String substringBeforeLast(String pattern) {
    return _substringBeforeLastImpl(this, pattern);
  }

  String substringAfterLast(String pattern) {
    return _substringAfterLastImpl(this, pattern);
  }

  String unescapedJson() {
    return _unescapedJsonStringImpl(this);
  }
}

extension LetExtension<T> on T {
  R let<R>(R Function(T) block) {
    return block(this);
  }
}
