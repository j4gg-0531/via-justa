import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Extrae el texto legible de un archivo PDF local sin enviarlo por red (`RN-10`).
///
/// Soporta:
/// - Flujos (`stream ... endstream`) sin comprimir y comprimidos con `/FlateDecode` (`zlib`).
/// - Mapas de caracteres `/ToUnicode` (`beginbfchar` / `beginbfrange`) para fuentes con glifos hex.
/// - Posicionamiento vertical real (`Tm`, `Td`, `TD`, `T*`, `'`, `"`) para unir fragmentos
///   de una misma línea (evitando palabras cortadas como `así c\nomo` o saltos falsos entre
///   bloques `BT ... ET` consecutivos en la misma coordenada Y).
Future<String> extractTextFromPdfFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return '';
  final bytes = await file.readAsBytes();
  return extractTextFromPdfBytes(bytes);
}

/// Extrae el texto legible a partir de los bytes de un documento PDF.
String extractTextFromPdfBytes(Uint8List bytes) {
  if (bytes.length < 8) return '';
  final raw = latin1.decode(bytes, allowInvalid: true);
  if (!raw.contains('%PDF-')) return '';

  final decodedStreams = <String>[];
  final toUnicodeMap = <int, String>{};

  var searchIndex = 0;
  while (searchIndex < raw.length) {
    final streamToken = _findStreamStart(raw, searchIndex);
    if (streamToken == null) break;

    final dataStart = streamToken.dataStart;
    final endStreamIndex = raw.indexOf('endstream', dataStart);
    if (endStreamIndex < 0) break;

    var dataEnd = endStreamIndex;
    if (dataEnd > dataStart && raw.codeUnitAt(dataEnd - 1) == 0x0A) {
      dataEnd--;
      if (dataEnd > dataStart && raw.codeUnitAt(dataEnd - 1) == 0x0D) {
        dataEnd--;
      }
    } else if (dataEnd > dataStart && raw.codeUnitAt(dataEnd - 1) == 0x0D) {
      dataEnd--;
    }

    final headerStart = (streamToken.keywordIndex - 256).clamp(
      0,
      streamToken.keywordIndex,
    );
    final dictSnippet = raw.substring(headerStart, streamToken.keywordIndex);
    final streamBytes = Uint8List.sublistView(bytes, dataStart, dataEnd);
    final decoded = _decodePdfStream(streamBytes, dictSnippet);

    if (decoded != null && decoded.isNotEmpty) {
      if (decoded.contains('beginbfchar') || decoded.contains('beginbfrange')) {
        _parseToUnicodeCMap(decoded, toUnicodeMap);
      }
      // Ignorar flujos de fuentes binarias (`/Length1`) que puedan contener los bytes 'BT'/'ET' por azar.
      final isFontProgram = dictSnippet.contains('/Length1') ||
          dictSnippet.contains('/Subtype/Type1C') ||
          dictSnippet.contains('/Subtype/CIDFontType0C');
      if (!isFontProgram &&
          _findOperator(decoded, 'BT', 0) >= 0 &&
          _findOperator(decoded, 'ET', 0) >= 0) {
        decodedStreams.add(decoded);
      }
    }

    searchIndex = endStreamIndex + 'endstream'.length;
  }

  if (decodedStreams.isEmpty) return '';

  final buffer = StringBuffer();
  for (var pageIdx = 0; pageIdx < decodedStreams.length; pageIdx++) {
    var streamContent = decodedStreams[pageIdx];
    // En páginas 2 en adelante, omitimos bloques `/Artifact ... BDC ... EMC` (encabezados/pies repetidos)
    // para que no corten frases que continúan de una página a la siguiente.
    if (pageIdx > 0) {
      streamContent = _stripPaginationArtifacts(streamContent);
    }
    final pageText = _extractTextFromContentStream(streamContent, toUnicodeMap);
    if (pageText.trim().isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write('\n\n');
      }
      buffer.write(pageText.trim());
    }
  }

  return _cleanExtractedDocumentText(buffer.toString());
}

final RegExp _artifactBlockPattern = RegExp(
  r'/Artifact\b[\s\S]*?BDC[\s\S]*?EMC',
);

String _stripPaginationArtifacts(String contentStream) {
  return contentStream.replaceAll(_artifactBlockPattern, ' ');
}

/// Limpia espacios redundantes y líneas de formulario vacías excesivas conservando cláusulas y estructura.
String _cleanExtractedDocumentText(String rawText) {
  final rawLines = rawText.split('\n');
  final cleanedLines = <String>[];

  for (final line in rawLines) {
    final compact = line
        .replaceAll(RegExp(r'_{5,}'), '____')
        .replaceAll(RegExp(r'[xX]{6,}'), 'xxxx')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    cleanedLines.add(compact);
  }

  final joined = cleanedLines.join('\n');
  return joined.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

class _StreamStart {
  const _StreamStart({required this.keywordIndex, required this.dataStart});

  final int keywordIndex;
  final int dataStart;
}

_StreamStart? _findStreamStart(String raw, int fromIndex) {
  var index = fromIndex;
  while (index < raw.length) {
    final pos = raw.indexOf('stream', index);
    if (pos < 0) return null;

    final isEndStream = pos >= 3 && raw.substring(pos - 3, pos) == 'end';
    final afterPos = pos + 'stream'.length;
    if (!isEndStream && afterPos < raw.length) {
      final nextChar = raw.codeUnitAt(afterPos);
      if (nextChar == 0x0A) {
        return _StreamStart(keywordIndex: pos, dataStart: afterPos + 1);
      }
      if (nextChar == 0x0D) {
        final hasLf =
            afterPos + 1 < raw.length && raw.codeUnitAt(afterPos + 1) == 0x0A;
        return _StreamStart(
          keywordIndex: pos,
          dataStart: afterPos + (hasLf ? 2 : 1),
        );
      }
    }
    index = afterPos;
  }
  return null;
}

String? _decodePdfStream(Uint8List streamBytes, String dictSnippet) {
  if (streamBytes.isEmpty) return null;
  if (dictSnippet.contains('/DCTDecode') ||
      dictSnippet.contains('/JPXDecode') ||
      dictSnippet.contains('/CCITTFaxDecode') ||
      dictSnippet.contains('/Length1')) {
    return null;
  }
  final usesFlate = dictSnippet.contains('/FlateDecode');
  if (usesFlate) {
    try {
      final inflated = zlib.decode(streamBytes);
      return latin1.decode(inflated, allowInvalid: true);
    } catch (_) {
      return null;
    }
  }
  final plain = latin1.decode(streamBytes, allowInvalid: true);
  if (plain.contains('BT') ||
      plain.contains('beginbfchar') ||
      plain.contains('beginbfrange')) {
    return plain;
  }
  try {
    final inflated = zlib.decode(streamBytes);
    return latin1.decode(inflated, allowInvalid: true);
  } catch (_) {
    return null;
  }
}

final RegExp _bfCharSectionPattern = RegExp(
  r'beginbfchar([\s\S]*?)endbfchar',
);
final RegExp _bfCharPairPattern = RegExp(
  r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
);
final RegExp _bfRangeSectionPattern = RegExp(
  r'beginbfrange([\s\S]*?)endbfrange',
);
final RegExp _bfRangeEntryPattern = RegExp(
  r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
);

void _parseToUnicodeCMap(String cmapContent, Map<int, String> target) {
  for (final section in _bfCharSectionPattern.allMatches(cmapContent)) {
    final body = section.group(1) ?? '';
    for (final pair in _bfCharPairPattern.allMatches(body)) {
      final src = int.tryParse(pair.group(1)!, radix: 16);
      final dstHex = pair.group(2)!;
      final decoded = _hexToUnicodeString(dstHex);
      if (src != null && decoded.isNotEmpty) {
        target[src] = decoded;
      }
    }
  }

  for (final section in _bfRangeSectionPattern.allMatches(cmapContent)) {
    final body = section.group(1) ?? '';
    for (final entry in _bfRangeEntryPattern.allMatches(body)) {
      final start = int.tryParse(entry.group(1)!, radix: 16);
      final end = int.tryParse(entry.group(2)!, radix: 16);
      final targetStart = int.tryParse(entry.group(3)!, radix: 16);
      if (start == null || end == null || targetStart == null || end < start) {
        continue;
      }
      final limit = (end - start).clamp(0, 1024);
      for (var offset = 0; offset <= limit; offset++) {
        target[start + offset] = String.fromCharCode(targetStart + offset);
      }
    }
  }
}

String _hexToUnicodeString(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  if (clean.isEmpty) return '';
  if (clean.length >= 4 && clean.length.isEven) {
    final codeUnits = <int>[];
    for (var i = 0; i + 4 <= clean.length; i += 4) {
      final unit = int.tryParse(clean.substring(i, i + 4), radix: 16);
      if (unit != null && unit > 0) {
        codeUnits.add(unit);
      }
    }
    if (codeUnits.isNotEmpty) {
      return String.fromCharCodes(codeUnits);
    }
  }
  final single = int.tryParse(clean, radix: 16);
  if (single != null && single > 0) {
    return String.fromCharCode(single);
  }
  return '';
}

class _LineCursorState {
  double? lastY;
  bool hasPositionOperators = false;
}

String _extractTextFromContentStream(
  String content,
  Map<int, String> toUnicodeMap,
) {
  final output = StringBuffer();
  final cursor = _LineCursorState();
  var index = 0;

  while (index < content.length) {
    final btIndex = _findOperator(content, 'BT', index);
    if (btIndex < 0) break;
    final etIndex = _findOperator(content, 'ET', btIndex + 2);
    final blockEnd = etIndex < 0 ? content.length : etIndex;
    final block = content.substring(btIndex + 2, blockEnd);

    _parseTextBlock(block, toUnicodeMap, output, cursor);

    // Si el PDF no usa coordenadas `Tm`/`Td` explícitas entre bloques `BT..ET`, separar por salto.
    if (!cursor.hasPositionOperators &&
        output.isNotEmpty &&
        !output.toString().endsWith('\n')) {
      output.write('\n');
    }

    index = blockEnd + 2;
  }

  return output.toString();
}

int _findOperator(String text, String op, int start) {
  var pos = start;
  while (pos < text.length) {
    final found = text.indexOf(op, pos);
    if (found < 0) return -1;
    final beforeOk = found == 0 || _isDelimiter(text.codeUnitAt(found - 1));
    final afterIdx = found + op.length;
    final afterOk =
        afterIdx >= text.length || _isDelimiter(text.codeUnitAt(afterIdx));
    if (beforeOk && afterOk) return found;
    pos = afterIdx;
  }
  return -1;
}

bool _isDelimiter(int codeUnit) {
  return codeUnit <= 0x20 ||
      codeUnit == 0x28 || // (
      codeUnit == 0x29 || // )
      codeUnit == 0x3C || // <
      codeUnit == 0x3E || // >
      codeUnit == 0x5B || // [
      codeUnit == 0x5D || // ]
      codeUnit == 0x2F; // /
}

void _parseTextBlock(
  String block,
  Map<int, String> toUnicodeMap,
  StringBuffer output,
  _LineCursorState cursor,
) {
  var i = 0;
  var pendingLiteralOrHex = '';
  final numericOperands = <double>[];

  while (i < block.length) {
    final cu = block.codeUnitAt(i);

    if (cu <= 0x20) {
      i++;
      continue;
    }

    // Comentarios `% ... \n`
    if (cu == 0x25) {
      while (i < block.length &&
          block.codeUnitAt(i) != 0x0A &&
          block.codeUnitAt(i) != 0x0D) {
        i++;
      }
      continue;
    }

    // Cadena literal `(...)`
    if (cu == 0x28) {
      final parsed = _readLiteralString(block, i);
      pendingLiteralOrHex = parsed.value;
      numericOperands.clear();
      i = parsed.nextIndex;
      continue;
    }

    // Cadena hexadecimal `<...>` (pero no diccionario `<<`)
    if (cu == 0x3C) {
      if (i + 1 < block.length && block.codeUnitAt(i + 1) == 0x3C) {
        i += 2;
        continue;
      }
      final parsed = _readHexString(block, i, toUnicodeMap);
      pendingLiteralOrHex = parsed.value;
      numericOperands.clear();
      i = parsed.nextIndex;
      continue;
    }

    // Arreglo `[...] TJ`
    if (cu == 0x5B) {
      final parsed = _readTextArray(block, i, toUnicodeMap);
      pendingLiteralOrHex = parsed.value;
      numericOperands.clear();
      i = parsed.nextIndex;
      continue;
    }

    // Nombre PDF `/F1` etc.
    if (cu == 0x2F) {
      i++;
      while (i < block.length && !_isDelimiter(block.codeUnitAt(i))) {
        i++;
      }
      numericOperands.clear();
      continue;
    }

    // Leer token/número/operador
    final tokenStart = i;
    while (i < block.length && !_isDelimiter(block.codeUnitAt(i))) {
      i++;
    }
    if (i == tokenStart) {
      i++;
      continue;
    }
    final token = block.substring(tokenStart, i);
    final asNumber = double.tryParse(token);
    if (asNumber != null) {
      numericOperands.add(asNumber);
      continue;
    }

    if (token == 'Tm') {
      // `a b c d e f Tm` -> `f` (último operando) es la coordenada vertical Y.
      if (numericOperands.length >= 6) {
        cursor.hasPositionOperators = true;
        final y = numericOperands[numericOperands.length - 1];
        if (cursor.lastY != null && (y - cursor.lastY!).abs() >= 2.0) {
          _appendNewlineIfNeeded(output);
        }
        cursor.lastY = y;
      }
    } else if (token == 'Td' || token == 'TD') {
      // `tx ty Td` -> si `ty` != 0, hay desplazamiento vertical a una nueva línea.
      if (numericOperands.length >= 2) {
        cursor.hasPositionOperators = true;
        final ty = numericOperands[numericOperands.length - 1];
        if (ty.abs() >= 1.0) {
          _appendNewlineIfNeeded(output);
          if (cursor.lastY != null) {
            cursor.lastY = cursor.lastY! + ty;
          }
        }
      } else {
        _appendNewlineIfNeeded(output);
      }
    } else if (token == 'T*') {
      _appendNewlineIfNeeded(output);
    } else if (token == 'Tj' || token == 'TJ') {
      if (pendingLiteralOrHex.isNotEmpty) {
        output.write(pendingLiteralOrHex);
        pendingLiteralOrHex = '';
      }
    } else if (token == "'" || token == '"') {
      _appendNewlineIfNeeded(output);
      if (pendingLiteralOrHex.isNotEmpty) {
        output.write(pendingLiteralOrHex);
        pendingLiteralOrHex = '';
      }
    }

    numericOperands.clear();
  }
}

void _appendNewlineIfNeeded(StringBuffer output) {
  if (output.isEmpty) return;
  final current = output.toString();
  if (!current.endsWith('\n')) {
    output.write('\n');
  }
}

class _ParsedToken {
  const _ParsedToken({required this.value, required this.nextIndex});

  final String value;
  final int nextIndex;
}

_ParsedToken _readLiteralString(String text, int startParenIndex) {
  final rawBytes = <int>[];
  var i = startParenIndex + 1;
  var depth = 1;

  while (i < text.length && depth > 0) {
    final cu = text.codeUnitAt(i);
    if (cu == 0x5C) {
      i++;
      if (i >= text.length) break;
      final esc = text.codeUnitAt(i);
      if (esc >= 0x30 && esc <= 0x37) {
        var octalStr = String.fromCharCode(esc);
        for (var k = 0; k < 2 && i + 1 < text.length; k++) {
          final nextCu = text.codeUnitAt(i + 1);
          if (nextCu >= 0x30 && nextCu <= 0x37) {
            octalStr += String.fromCharCode(nextCu);
            i++;
          } else {
            break;
          }
        }
        final value = int.tryParse(octalStr, radix: 8);
        if (value != null) {
          rawBytes.add(value & 0xFF);
        }
      } else if (esc == 0x6E) {
        rawBytes.add(0x0A);
      } else if (esc == 0x72) {
        rawBytes.add(0x0A);
      } else if (esc == 0x74) {
        rawBytes.add(0x09);
      } else if (esc == 0x0D || esc == 0x0A) {
        if (esc == 0x0D &&
            i + 1 < text.length &&
            text.codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
      } else {
        rawBytes.add(esc & 0xFF);
      }
      i++;
      continue;
    }

    if (cu == 0x28) {
      depth++;
      rawBytes.add(cu);
    } else if (cu == 0x29) {
      depth--;
      if (depth > 0) {
        rawBytes.add(cu);
      }
    } else {
      rawBytes.add(cu & 0xFF);
    }
    i++;
  }

  return _ParsedToken(
    value: _decodePdfBytesToText(rawBytes),
    nextIndex: i,
  );
}

String _decodePdfBytesToText(List<int> bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    final units = <int>[];
    for (var i = 2; i + 1 < bytes.length; i += 2) {
      final unit = (bytes[i] << 8) | bytes[i + 1];
      if (unit > 0) units.add(unit);
    }
    return String.fromCharCodes(units);
  }
  return String.fromCharCodes(bytes);
}

_ParsedToken _readHexString(
  String text,
  int startAngleIndex,
  Map<int, String> toUnicodeMap,
) {
  final endIndex = text.indexOf('>', startAngleIndex + 1);
  if (endIndex < 0) {
    return _ParsedToken(value: '', nextIndex: text.length);
  }
  final hex = text
      .substring(startAngleIndex + 1, endIndex)
      .replaceAll(RegExp(r'\s+'), '');
  if (hex.isEmpty) {
    return _ParsedToken(value: '', nextIndex: endIndex + 1);
  }

  final padded = hex.length.isOdd ? '${hex}0' : hex;
  final buffer = StringBuffer();

  final hasTwoByteKeys = toUnicodeMap.keys.any((k) => k > 0xFF);
  if (hasTwoByteKeys && padded.length % 4 == 0) {
    var matchedAll = true;
    final temp = StringBuffer();
    for (var i = 0; i + 4 <= padded.length; i += 4) {
      final code = int.tryParse(padded.substring(i, i + 4), radix: 16);
      final mapped = code != null ? toUnicodeMap[code] : null;
      if (mapped != null) {
        temp.write(mapped);
      } else {
        matchedAll = false;
        break;
      }
    }
    if (matchedAll && temp.isNotEmpty) {
      return _ParsedToken(value: temp.toString(), nextIndex: endIndex + 1);
    }
  }

  final rawBytes = <int>[];
  for (var i = 0; i + 2 <= padded.length; i += 2) {
    final byteVal = int.tryParse(padded.substring(i, i + 2), radix: 16) ?? 0;
    if (toUnicodeMap.containsKey(byteVal)) {
      buffer.write(toUnicodeMap[byteVal]);
    } else {
      rawBytes.add(byteVal);
    }
  }

  if (rawBytes.isNotEmpty) {
    buffer.write(_decodePdfBytesToText(rawBytes));
  }

  return _ParsedToken(value: buffer.toString(), nextIndex: endIndex + 1);
}

_ParsedToken _readTextArray(
  String text,
  int startBracketIndex,
  Map<int, String> toUnicodeMap,
) {
  final buffer = StringBuffer();
  var i = startBracketIndex + 1;

  while (i < text.length) {
    final cu = text.codeUnitAt(i);
    if (cu <= 0x20) {
      i++;
      continue;
    }
    if (cu == 0x5D) {
      i++;
      break;
    }
    if (cu == 0x28) {
      final lit = _readLiteralString(text, i);
      buffer.write(lit.value);
      i = lit.nextIndex;
      continue;
    }
    if (cu == 0x3C) {
      final hex = _readHexString(text, i, toUnicodeMap);
      buffer.write(hex.value);
      i = hex.nextIndex;
      continue;
    }
    final numStart = i;
    while (i < text.length && !_isDelimiter(text.codeUnitAt(i))) {
      i++;
    }
    if (i > numStart) {
      final kerning = double.tryParse(text.substring(numStart, i));
      if (kerning != null && kerning <= -180) {
        final current = buffer.toString();
        if (current.isNotEmpty && !current.endsWith(' ')) {
          buffer.write(' ');
        }
      }
    } else {
      i++;
    }
  }

  return _ParsedToken(value: buffer.toString(), nextIndex: i);
}
