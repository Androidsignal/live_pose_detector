import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../config/pose_overlay_config.dart';
import '../detection/pose_stream_controller.dart';

/// Draws the skeleton (dots + connecting lines) for the latest [PoseFrame]
/// over the camera preview.
///
/// Landmarks below [PoseOverlayConfig.confidenceThreshold] are skipped
/// entirely — both as dots and as line endpoints — so jittery/low-likelihood
/// points don't flicker on screen.
///
/// Front-camera mirroring is **not** done here — [CameraPoseView] flips the
/// whole preview+overlay `Stack` together with one `Transform`, so the
/// skeleton and the video it's drawn over always move in lockstep
/// regardless of which way the raw camera buffer is mirrored.
class PoseOverlayPainter extends CustomPainter {
  PoseOverlayPainter({required this.frame, required this.config});

  final PoseFrame? frame;
  final PoseOverlayConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = this.frame;
    if (frame == null || frame.poses.isEmpty) return;

    // A dark, semi-transparent halo drawn under the colored strokes keeps
    // the skeleton legible over both light and dark backgrounds.
    final lineHaloPaint = Paint()
      ..color = config.haloColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.lineWidth + 3
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = config.lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = config.lineWidth
      ..strokeCap = StrokeCap.round;
    final dotHaloPaint = Paint()
      ..color = config.haloColor
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = config.dotColor
      ..style = PaintingStyle.fill;

    for (final pose in frame.poses) {
      // Halos first, then colored lines, then halo dots, then colored dots
      // — each layer renders on top of the last so joins/dots stay crisp.
      for (final pair in config.connections) {
        final a = pose.landmarks[pair[0]];
        final b = pose.landmarks[pair[1]];
        if (a == null || b == null) continue;
        if (a.likelihood < config.confidenceThreshold ||
            b.likelihood < config.confidenceThreshold) {
          continue;
        }
        final pointA = mapPoint(Offset(a.x, a.y), frame, size);
        final pointB = mapPoint(Offset(b.x, b.y), frame, size);
        canvas.drawLine(pointA, pointB, lineHaloPaint);
        canvas.drawLine(pointA, pointB, linePaint);
      }

      for (final landmark in pose.landmarks.values) {
        if (landmark.likelihood < config.confidenceThreshold) continue;
        final point = mapPoint(Offset(landmark.x, landmark.y), frame, size);
        canvas.drawCircle(point, config.dotRadius + 1.5, dotHaloPaint);
        canvas.drawCircle(point, config.dotRadius, dotPaint);
      }
    }
  }

  /// Maps a raw landmark point in [InputImage] pixel space to canvas
  /// space.
  ///
  /// ML Kit never rotates `x`/`y` into each other — a landmark's `x` always
  /// contributes to the mapped X, `y` always to the mapped Y. Only the
  /// *scale divisor* changes with rotation, and — a genuine platform
  /// quirk, not a mistake — that divisor swap happens on Android but not
  /// on iOS at 90°/270°. 270° also gets an unconditional X-flip that's
  /// part of making the buffer upright, distinct from front-camera
  /// mirroring (which [CameraPoseView] applies separately, once, to
  /// preview+overlay together). This matches the reference
  /// `coordinates_translator.dart` shipped with the official
  /// `google_mlkit_pose_detection` example — see
  /// https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
  ///
  /// From upright-but-unscaled space, this then applies the **same math as
  /// `BoxFit.cover`** — one uniform scale (`max` of the two per-axis
  /// ratios), then centered — so a landmark lines up with wherever the
  /// full-bleed `CameraPreview` actually draws that pixel. (The official
  /// reference doesn't need this step: its example doesn't crop to fill
  /// the screen, so its canvas is already aspect-matched to the upright
  /// image.)
  @visibleForTesting
  Offset mapPoint(Offset point, PoseFrame frame, Size canvasSize) {
    final imageSize = frame.imageSize;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final rotated = rotatesDimensions(frame.rotation);

    final targetWidth = rotated ? imageSize.height : imageSize.width;
    final targetHeight = rotated ? imageSize.width : imageSize.height;
    final xDivisor = rotated ? (isIOS ? imageSize.width : imageSize.height) : imageSize.width;
    final yDivisor = rotated ? (isIOS ? imageSize.height : imageSize.width) : imageSize.height;

    var x = point.dx / xDivisor * targetWidth;
    final y = point.dy / yDivisor * targetHeight;
    if (frame.rotation == InputImageRotation.rotation270deg) {
      x = targetWidth - x;
    }

    // BoxFit.cover: scale uniformly by whichever ratio is larger (so the
    // shorter canvas axis is exactly filled), then center — the longer
    // axis overflows the canvas symmetrically and gets clipped.
    final scale = math.max(
      canvasSize.width / targetWidth,
      canvasSize.height / targetHeight,
    );
    final offsetX = (canvasSize.width - targetWidth * scale) / 2;
    final offsetY = (canvasSize.height - targetHeight * scale) / 2;

    return Offset(x * scale + offsetX, y * scale + offsetY);
  }

  /// Whether [rotation] swaps width/height when mapping into upright
  /// (canvas) space.
  @visibleForTesting
  bool rotatesDimensions(InputImageRotation rotation) {
    return rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.frame?.poses != frame?.poses ||
        oldDelegate.frame?.imageSize != frame?.imageSize ||
        oldDelegate.frame?.rotation != frame?.rotation ||
        oldDelegate.frame?.lensDirection != frame?.lensDirection ||
        oldDelegate.config.dotColor != config.dotColor ||
        oldDelegate.config.lineColor != config.lineColor ||
        oldDelegate.config.dotRadius != config.dotRadius ||
        oldDelegate.config.lineWidth != config.lineWidth ||
        oldDelegate.config.haloColor != config.haloColor ||
        oldDelegate.config.confidenceThreshold != config.confidenceThreshold ||
        oldDelegate.config.connections != config.connections;
  }
}
