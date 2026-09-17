// dart run tool/make_icon.dart
//
// Loads teleprompter_app_icon.png, removes the light background by
// flood-filling from all four corners, then writes logo.png ready for
// flutter_launcher_icons.

import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const src = 'assets/logo/teleprompter_app_icon.png';
  const dst = 'assets/logo/logo.png';

  print('Loading $src …');
  final bytes = File(src).readAsBytesSync();
  final image = img.decodeImage(bytes)!;

  final w = image.width;
  final h = image.height;

  // Sample background colour from the top-left corner pixel.
  final corner = image.getPixel(0, 0);
  final bgR = corner.r.toInt();
  final bgG = corner.g.toInt();
  final bgB = corner.b.toInt();
  print('Background colour sampled: rgb($bgR, $bgG, $bgB)');

  // BFS flood-fill mask — tracks which pixels have been visited.
  final visited = List.filled(w * h, false);
  final queue = Queue<int>();

  // Seed from all four corners.
  for (final idx in [0, w - 1, (h - 1) * w, h * w - 1]) {
    if (!visited[idx]) {
      visited[idx] = true;
      queue.add(idx);
    }
  }

  // Threshold: pixels within this distance of the background colour are
  // considered background. Raised a little to eat into the anti-aliased fringe.
  const threshold = 60;

  bool isBackground(img.Pixel p) {
    final dr = (p.r.toInt() - bgR).abs();
    final dg = (p.g.toInt() - bgG).abs();
    final db = (p.b.toInt() - bgB).abs();
    return dr + dg + db < threshold;
  }

  // BFS — flood the background region.
  final bgMask = List.filled(w * h, false);
  while (queue.isNotEmpty) {
    final idx = queue.removeFirst();
    final x = idx % w;
    final y = idx ~/ w;
    final p = image.getPixel(x, y);

    if (!isBackground(p)) continue;
    bgMask[idx] = true;

    for (final (nx, ny) in [
      (x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1),
    ]) {
      if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
      final ni = ny * w + nx;
      if (!visited[ni]) {
        visited[ni] = true;
        queue.add(ni);
      }
    }
  }

  // Build output image: background pixels → transparent,
  // anti-aliased fringe → partial alpha, interior → fully opaque.
  final out = img.Image(width: w, height: h);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final idx = y * w + x;
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      if (bgMask[idx]) {
        // Flood-filled background → fully transparent.
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        // Check colour distance for soft edge blending.
        final dr = (r - bgR).abs();
        final dg = (g - bgG).abs();
        final db = (b - bgB).abs();
        final dist = dr + dg + db;

        if (dist < threshold * 2) {
          // Anti-aliased fringe — fade alpha proportionally.
          final alpha = ((dist - threshold) / threshold * 255)
              .round()
              .clamp(0, 255);
          out.setPixelRgba(x, y, r, g, b, alpha);
        } else {
          // Solid icon interior → fully opaque.
          out.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }
  }

  print('Writing $dst …');
  File(dst).writeAsBytesSync(img.encodePng(out));
  print('Done. ${File(dst).lengthSync()} bytes written.');
}
