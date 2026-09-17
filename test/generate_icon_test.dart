// Run with: flutter test test/generate_icon_test.dart
// Renders AppLogo at 1024×1024 and writes assets/logo/logo.png,
// which flutter_launcher_icons then uses to stamp all platform icon sizes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/widgets/app_logo.dart';

void main() {
  testWidgets('export app icon as PNG', (tester) async {
    // Give the test surface enough room for a 1024×1024 render
    await tester.binding.setSurfaceSize(const Size(1024, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final key = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: const AppLogo(size: 1024),
        ),
      ),
    );

    await tester.pump();

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final outFile = File('assets/logo/logo.png');
    await outFile.writeAsBytes(bytes);

    // ignore: avoid_print
    print('✓ Icon written to ${outFile.absolute.path}');
    expect(outFile.existsSync(), true);
  });
}
