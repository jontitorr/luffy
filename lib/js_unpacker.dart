import "dart:core";
import "dart:math";

import "package:luffy/util.dart";

class Unbaser {
  Unbaser(this.base)
      : selector = (base > 62)
            ? 95
            : (base > 54)
                ? 62
                : (base > 52)
                    ? 54
                    : 52,
        alphabet = {
          52: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP",
          54: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR",
          62: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
          95: " !\"#\$%&\\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~",
        };

  final int base;
  final int selector;
  final Map<int, String> alphabet;

  int unbase(String value) {
    if (base >= 2 && base <= 36) {
      return int.tryParse(value, radix: base) ?? 0;
    }

    final dict = alphabet[selector]?.split("").asMap();

    var returnVal = 0;
    final valArray = value.codeUnits.toList();

    for (int i = 0; i < valArray.length; i++) {
      final cipher = valArray[i];
      final cipherIndex = (dict?[cipher] ?? 0) as int;
      returnVal += (pow(base, i) * cipherIndex).toInt();
    }

    return returnVal;
  }
}

class JsUnpacker {
  static bool detect(String str) => packedRegex.hasMatch(str);

  static final RegExp packedRegex = RegExp(
    r"eval[(]function[(]p,a,c,k,e,[r|d]?",
    caseSensitive: false,
    multiLine: true,
  );

  /// Regex to get and group the packed javascript.
  /// Needed to get information and unpack the code.
  static final RegExp packedExtractRegex = RegExp(
    r"[}][(]'(.*)', *(\\d+), *(\\d+), *'(.*?)'[.]split[(]'[|]'[)]",
    caseSensitive: false,
    multiLine: true,
  );

  /// Matches function names and variables to de-obfuscate the code.
  static final RegExp unpackReplaceRegex =
      RegExp(r"\\b\\w+\\b", caseSensitive: false, multiLine: true);

  static Iterable<String> unpacking(String scriptBlock) {
    return packedExtractRegex.allMatches(scriptBlock).mapNotNull((result) {
      final payload = result.group(1);
      final symtab = result.group(4)?.split("|");
      final radix = int.tryParse(result.group(2) ?? "") ?? 10;
      final count = int.tryParse(result.group(3) ?? "");
      final unbaser = Unbaser(radix);

      if (symtab == null || count == null || symtab.length != count) {
        return null;
      }

      return payload?.replaceAllMapped(unpackReplaceRegex, (match) {
        final word = match.group(0) ?? "";
        final unbased = symtab[unbaser.unbase(word)];
        return unbased.isEmpty ? word : unbased;
      });
    });
  }

  static Iterable<String> unpack(String scriptBlock) {
    if (!detect(scriptBlock)) {
      return [];
    }

    return unpacking(scriptBlock);
  }

  static List<String> unpackList(List<String> scriptBlock) {
    return scriptBlock.mapNotNull((it) => it.contains(packedRegex) ? it : null);
  }

  static String? unpackAndCombine(String scriptBlock) {
    final unpacked = unpack(scriptBlock);

    if (unpacked.isEmpty) {
      return null;
    }

    return unpacked.join(" ");
  }
}
