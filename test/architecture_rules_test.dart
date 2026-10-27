import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Architecture Rule 5.2 - Presentation layers contain no forbidden business logic or data access', () {
    final presentationDir = Directory('lib');
    expect(presentationDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final forbiddenPattern = RegExp(
      r'normalizeForSearch|search[A-Z]\w*\(|\.where\(|\.sort\(|firstWhere|jsonDecode|rootBundle|Timer|Future\.delayed',
    );

    final violations = <String>[];

    final dartFiles = presentationDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final normalizedPath = file.path.replaceAll(r'\', '/');

      // Solo evaluamos archivos en presentation/, excluyendo presentation/state/
      if (normalizedPath.contains('/presentation/') && !normalizedPath.contains('/presentation/state/')) {
        // Excepción temporal aceptada en AGENTS.md: Timer de splash_page.dart
        if (normalizedPath.endsWith('splash_page.dart')) {
          continue;
        }

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (forbiddenPattern.hasMatch(line)) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Se encontraron violaciones a la Regla 5.2 de AGENTS.md en capas de presentación:\n'
          '${violations.join('\n')}',
    );
  });
}
