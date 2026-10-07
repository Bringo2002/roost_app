import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the monochrome design system: colors come from `AppColors` (or
/// `AmenityColors` for the amenity picker), never from raw literals or the
/// chromatic Material colors. Neutral Material colors (`Colors.white`,
/// `Colors.black`, `Colors.transparent`, `Colors.grey[..]`) are allowed.

/// The only files allowed to define raw colors.
const _allowedFiles = <String>{
  'lib/theme/app_colors.dart',
  'lib/theme/amenity_colors.dart',
};

/// Generated sources are not hand-written, so they are not checked.
const _skippedPrefixes = <String>['lib/l10n/generated/'];

const _chromatic = 'red|pink|purple|deepPurple|indigo|blue|lightBlue|cyan|teal|'
    'green|lightGreen|lime|yellow|amber|orange|deepOrange|brown';

final _rules = <String, RegExp>{
  'raw hex Color literal': RegExp(r'\bColor\(\s*0x[0-9A-Fa-f]+\s*\)'),
  'Color.fromARGB / fromRGBO': RegExp(r'\bColor\.from(ARGB|RGBO)\('),
  'chromatic Material color': RegExp('\\bColors\\.($_chromatic)(Accent)?\\b'),
};

/// Returns one `line N [rule]: text` entry per violation in [source].
/// Whole-line comments are ignored so documentation can mention colors.
List<String> findColorViolations(String source) {
  final violations = <String>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    for (final rule in _rules.entries) {
      if (rule.value.hasMatch(line)) {
        violations.add('line ${i + 1} [${rule.key}]: ${line.trim()}');
      }
    }
  }
  return violations;
}

void main() {
  group('findColorViolations', () {
    // A broken pattern would make the repo-wide check below pass vacuously,
    // so the detector itself is pinned here.
    const flagged = <String>[
      'Color(0xFF123456)',
      'const Color( 0xFF123456 )',
      'Color.fromARGB(255, 1, 2, 3)',
      'Color.fromRGBO(1, 2, 3, 0.5)',
      'Colors.red',
      'Colors.greenAccent',
      'Colors.amber.withValues(alpha: 0.2)',
    ];
    const allowed = <String>[
      'Colors.white',
      'Colors.black',
      'Colors.transparent',
      'Colors.grey[400]',
      'Colors.blueGrey',
      'AppColors.error',
      'AmenityColors.water',
      '// Colors.red mentioned in a comment',
      '/// Color(0xFF123456) mentioned in a doc comment',
    ];

    for (final source in flagged) {
      test('flags: $source', () {
        expect(findColorViolations(source), isNotEmpty);
      });
    }
    for (final source in allowed) {
      test('allows: $source', () {
        expect(findColorViolations(source), isEmpty);
      });
    }

    test('reports the line number and the rule', () {
      final result = findColorViolations('final a = 1;\nfinal b = Colors.red;');
      expect(result, hasLength(1));
      expect(result.single, startsWith('line 2 [chromatic Material color]'));
    });
  });

  group('theme discipline', () {
    test('no raw or chromatic colors outside the theme files', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue,
          reason: 'run flutter test from the package root');

      var scanned = 0;
      final violations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (_allowedFiles.contains(path)) continue;
        if (_skippedPrefixes.any(path.startsWith)) continue;

        scanned++;
        for (final violation in findColorViolations(entity.readAsStringSync())) {
          violations.add('$path: $violation');
        }
      }

      expect(scanned, greaterThan(0), reason: 'the scan found no source files');
      expect(
        violations,
        isEmpty,
        reason: 'Use AppColors (or AmenityColors) instead of raw colors:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
