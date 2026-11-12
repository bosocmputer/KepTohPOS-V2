import 'dart:math' as math;
import 'dart:typed_data';

/// Result of converting an RGBA pixel buffer into a 1-bit packed monochrome
/// raster buffer (with trailing blank paper rows trimmed).
class MonochromeRaster {
  const new({
    required this.bytes,
    required this.widthDots,
    required this.heightRows,
    required this.bytesPerRow,
  });

  final Uint8List bytes;
  final int widthDots;
  final int heightRows;
  final int bytesPerRow;
}

/// ESC @ (`0x1B 0x40`): Initializes printer and resets modes.
Uint8List escInit() => Uint8List.fromList(const <int>[0x1B, 0x40]);

/// ESC d n (`0x1B 0x64 n`) + GS V B 0 (`0x1D 0x56 0x42 0x00`):
/// Feeds [lines] lines and performs a standard partial paper cut.
Uint8List escFeedAndCut([int lines = 4]) {
  final n = lines.clamp(0, 255);
  return Uint8List.fromList(<int>[0x1B, 0x64, n, 0x1D, 0x56, 0x42, 0x00]);
}

/// Converts an RGBA buffer (`width * height * 4` bytes) into 1-bit packed
/// monochrome bytes where `1` = black dot and `0` = white paper.
///
/// Uses hybrid Atkinson error-diffusion dithering:
/// - Pure dark pixels (`lum < 60`, e.g. Thai text and QR modules) lock to
///   solid black (`1`) with zero dither holes.
/// - Pure light pixels (`lum > 215`, e.g. paper background) lock to solid
///   white (`0`) with zero dither noise.
/// - Mid-tone/colored pixels (`60 <= lum <= 215`, e.g. orange or color shop
///   logos) are halftoned via Atkinson dithering so logos print crisply.
///
/// Also trims trailing all-white rows at the bottom (keeping a 16px quiet
/// margin) so receipts do not waste thermal paper.
MonochromeRaster rgbaToMonochromeRaster(
  Uint8List rgba,
  int width,
  int height, {
  int luminanceThreshold = 160,
  bool ditherMidtones = true,
}) {
  final bytesPerRow = (width + 7) >> 3;
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return MonochromeRaster(
      bytes: Uint8List(0),
      widthDots: math.max(0, width),
      heightRows: 0,
      bytesPerRow: math.max(0, bytesPerRow),
    );
  }

  final full = Uint8List(bytesPerRow * height);
  final err = ditherMidtones ? Int16List(width * height) : null;
  var lastNonEmptyRow = 0;

  for (var y = 0; y < height; y++) {
    final rowByteOffset = y * bytesPerRow;
    final rowPixelOffset = y * width * 4;
    final rowIdx = y * width;
    var rowHasBlack = false;

    for (var x = 0; x < width; x++) {
      final px = rowPixelOffset + (x << 2);
      final a = rgba[px + 3];
      if (a <= 128) continue;
      final r = rgba[px];
      final g = rgba[px + 1];
      final b = rgba[px + 2];
      // Integer ITU-R BT.601 luminance: (77*R + 150*G + 29*B) >> 8
      final baseLum = (77 * r + 150 * g + 29 * b) >> 8;

      bool isBlack;
      if (!ditherMidtones || baseLum < 60 || baseLum > 215) {
        isBlack = baseLum < luminanceThreshold;
      } else {
        final i = rowIdx + x;
        final adj = (baseLum + err![i]).clamp(0, 255);
        isBlack = adj < luminanceThreshold;
        final qErr = (adj - (isBlack ? 0 : 255)) >> 3; // Atkinson 1/8th
        if (qErr != 0) {
          if (x + 1 < width) err[i + 1] += qErr;
          if (x + 2 < width) err[i + 2] += qErr;
          if (y + 1 < height) {
            final nextRow = i + width;
            if (x > 0) err[nextRow - 1] += qErr;
            err[nextRow] += qErr;
            if (x + 1 < width) err[nextRow + 1] += qErr;
          }
          if (y + 2 < height) {
            err[i + width * 2] += qErr;
          }
        }
      }

      if (isBlack) {
        final byteIdx = rowByteOffset + (x >> 3);
        final bitMask = 1 << (7 - (x & 7));
        full[byteIdx] |= bitMask;
        rowHasBlack = true;
      }
    }

    if (rowHasBlack) {
      lastNonEmptyRow = y;
    }
  }

  final trimmedRows = math.min(height, math.max(1, lastNonEmptyRow + 1 + 16));
  final trimmedBytes = Uint8List.sublistView(
    full,
    0,
    trimmedRows * bytesPerRow,
  );
  return MonochromeRaster(
    bytes: Uint8List.fromList(trimmedBytes),
    widthDots: width,
    heightRows: trimmedRows,
    bytesPerRow: bytesPerRow,
  );
}

/// Builds a complete ESC/POS raster job:
/// `ESC @` + sequence of `GS v 0` (`0x1D 0x76 0x30 0x00 xL xH yL yH d1..dk`)
/// in horizontal bands of [maxBandRows] rows + `escFeedAndCut(4)`.
Uint8List encodeGsV0Chunks(
  Uint8List monoBytes,
  int widthDots,
  int heightRows, {
  int maxBandRows = 120,
}) {
  final bytesPerRow = (widthDots + 7) >> 3;
  final safeBandRows = math.max(1, maxBandRows);
  final builder = BytesBuilder(copy: false)..add(escInit());

  if (bytesPerRow > 0 && heightRows > 0 && monoBytes.isNotEmpty) {
    final totalAvailableRows = math.min(
      heightRows,
      monoBytes.length ~/ bytesPerRow,
    );
    final xL = bytesPerRow & 0xFF;
    final xH = (bytesPerRow >> 8) & 0xFF;

    for (var row = 0; row < totalAvailableRows; row += safeBandRows) {
      final bandRows = math.min(safeBandRows, totalAvailableRows - row);
      final yL = bandRows & 0xFF;
      final yH = (bandRows >> 8) & 0xFF;
      final start = row * bytesPerRow;
      final end = start + bandRows * bytesPerRow;

      builder
        ..add(const <int>[0x1D, 0x76, 0x30, 0x00])
        ..add(<int>[xL, xH, yL, yH])
        ..add(Uint8List.sublistView(monoBytes, start, end));
    }
  }

  builder.add(escFeedAndCut());
  return builder.toBytes();
}

/// Convenience pipeline combining [rgbaToMonochromeRaster] and
/// [encodeGsV0Chunks] into a single ready-to-send ESC/POS byte stream.
Uint8List encodeRgbaToEscPos(
  Uint8List rgba,
  int width,
  int height, {
  int luminanceThreshold = 160,
  int maxBandRows = 120,
}) {
  final raster = rgbaToMonochromeRaster(
    rgba,
    width,
    height,
    luminanceThreshold: luminanceThreshold,
  );
  return encodeGsV0Chunks(
    raster.bytes,
    raster.widthDots,
    raster.heightRows,
    maxBandRows: maxBandRows,
  );
}
