import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

File? _findFontFile(String relativePath) {
  final candidates = <String>[
    relativePath,
    'app/$relativePath',
    '../$relativePath',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

File? _findMaterialIconsFont() {
  const rel = 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[
    ?Platform.environment['FLUTTER_ROOT'],
    '/Users/nontawatwongnuk/development/flutter',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    roots.add(dir.path);
    dir = dir.parent;
  }
  for (final root in roots) {
    final file = File('$root/$rel');
    if (file.existsSync()) return file;
  }
  return null;
}

Future<void> _loadFontFamily(String family, List<String> assetPaths) async {
  final loader = FontLoader(family);
  for (final path in assetPaths) {
    final file = _findFontFile(path);
    if (file != null) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
  }
  await loader.load();
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadFontFamily('Anuphan', const <String>[
    'assets/fonts/Anuphan-Medium.ttf',
    'assets/fonts/Anuphan-SemiBold.ttf',
    'assets/fonts/Anuphan-Bold.ttf',
  ]);

  await _loadFontFamily('IBM Plex Sans Thai', const <String>[
    'assets/fonts/IBMPlexSansThai-Regular.ttf',
    'assets/fonts/IBMPlexSansThai-Medium.ttf',
    'assets/fonts/IBMPlexSansThai-SemiBold.ttf',
    'assets/fonts/IBMPlexSansThai-Bold.ttf',
  ]);

  await _loadFontFamily('HgiStrokeRounded', const <String>[
    'assets/fonts/hugeicons-stroke-rounded.ttf',
  ]);
  await _loadFontFamily('packages/hugeicons/HgiStrokeRounded', const <String>[
    'assets/fonts/hugeicons-stroke-rounded.ttf',
  ]);

  final materialFont = _findMaterialIconsFont();
  if (materialFont != null) {
    final bytes = materialFont.readAsBytesSync();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await testMain();
}
