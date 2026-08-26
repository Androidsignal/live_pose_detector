import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:live_pose_detector/live_pose_detector.dart';

void main() {
  const config = PoseOverlayConfig();
  final painter = PoseOverlayPainter(frame: null, config: config);

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('rotatesDimensions', () {
    test('90/270 degrees swap width and height', () {
      expect(painter.rotatesDimensions(InputImageRotation.rotation90deg), isTrue);
      expect(painter.rotatesDimensions(InputImageRotation.rotation270deg), isTrue);
    });

    test('0/180 degrees do not swap width and height', () {
      expect(painter.rotatesDimensions(InputImageRotation.rotation0deg), isFalse);
      expect(painter.rotatesDimensions(InputImageRotation.rotation180deg), isFalse);
    });
  });

  group('mapPoint', () {
    test('scales point from source image space to canvas space', () {
      const frame = PoseFrame(
        poses: [],
        imageSize: Size(200, 100),
        rotation: InputImageRotation.rotation0deg,
        lensDirection: CameraLensDirection.back,
      );

      final mapped = painter.mapPoint(
        const Offset(100, 50),
        frame,
        const Size(400, 200),
      );

      expect(mapped, const Offset(200, 100));
    });

    // At 90/270 degrees the scale divisor differs between Android and iOS
    // — a real, confirmed platform quirk (not a bug) matching the official
    // google_mlkit_pose_detection example's coordinates_translator.dart:
    // Android's divisor uses the *other* source dimension, iOS uses the
    // same one x/y already refer to. Neither platform ever swaps x and y.
    group('at 90 degrees', () {
      const imageSize = Size(200, 100);
      const point = Offset(50, 80);
      const canvasSize = Size(100, 200); // matches upright size 1:1

      test('Android: x uses imageHeight, y uses imageWidth as divisor', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const frame = PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: InputImageRotation.rotation90deg,
          lensDirection: CameraLensDirection.back,
        );
        // x = 50 / imageHeight(100) * targetWidth(100) = 50
        // y = 80 / imageWidth(200) * targetHeight(200) = 80
        expect(painter.mapPoint(point, frame, canvasSize), const Offset(50, 80));
      });

      test('iOS: x uses imageWidth, y uses imageHeight as divisor', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        const frame = PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: InputImageRotation.rotation90deg,
          lensDirection: CameraLensDirection.back,
        );
        // x = 50 / imageWidth(200) * targetWidth(100) = 25
        // y = 80 / imageHeight(100) * targetHeight(200) = 160
        expect(painter.mapPoint(point, frame, canvasSize), const Offset(25, 160));
      });
    });

    group('at 270 degrees', () {
      const imageSize = Size(200, 100);
      const point = Offset(30, 80);
      const canvasSize = Size(100, 200);

      test('Android: same divisor swap as 90deg, plus an X flip', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const frame = PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: InputImageRotation.rotation270deg,
          lensDirection: CameraLensDirection.back,
        );
        // x = 30/100*100 = 30, flipped: targetWidth(100) - 30 = 70
        // y = 80/200*200 = 80 (unflipped — only X flips at 270)
        expect(painter.mapPoint(point, frame, canvasSize), const Offset(70, 80));
      });

      test('iOS: same unswapped divisor as 90deg, plus an X flip', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        const frame = PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: InputImageRotation.rotation270deg,
          lensDirection: CameraLensDirection.back,
        );
        // x = 30/200*100 = 15, flipped: 100 - 15 = 85
        // y = 80/100*200 = 160
        expect(painter.mapPoint(point, frame, canvasSize), const Offset(85, 160));
      });
    });

    test('180 degrees is treated the same as 0 degrees (matches upstream reference)', () {
      const imageSize = Size(200, 100);
      const point = Offset(50, 20);
      const canvasSize = Size(200, 100); // 1:1 canvas

      final at0 = painter.mapPoint(
        point,
        const PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: InputImageRotation.rotation0deg,
          lensDirection: CameraLensDirection.back,
        ),
        canvasSize,
      );
      final at180 = painter.mapPoint(
        point,
        const PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: InputImageRotation.rotation180deg,
          lensDirection: CameraLensDirection.back,
        ),
        canvasSize,
      );

      expect(at180, at0);
      expect(at180, const Offset(50, 20));
    });

    test('does not mirror for front camera — mirroring is the widget\'s job', () {
      // CameraPoseView mirrors preview+overlay together with one Transform;
      // the painter itself must map identically regardless of lens.
      const imageSize = Size(100, 100);
      const rotation = InputImageRotation.rotation0deg;
      const point = Offset(20, 30);
      const canvasSize = Size(100, 100);

      final front = painter.mapPoint(
        point,
        const PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: rotation,
          lensDirection: CameraLensDirection.front,
        ),
        canvasSize,
      );
      final back = painter.mapPoint(
        point,
        const PoseFrame(
          poses: [],
          imageSize: imageSize,
          rotation: rotation,
          lensDirection: CameraLensDirection.back,
        ),
        canvasSize,
      );

      expect(front, back);
      expect(front, const Offset(20, 30));
    });

    test('matches BoxFit.cover uniform-scale-and-crop when aspect ratios differ', () {
      // 200x100 (2:1) upright buffer displayed in a 100x100 (1:1) canvas.
      // BoxFit.cover scales by the larger ratio (max(0.5, 1) = 1) so the
      // canvas height is exactly filled, then centers — cropping 50px off
      // each side of the width. Scaling each axis independently instead
      // (the old, wrong approach) would show the whole width squeezed in,
      // stretching the image instead of matching what's actually cropped.
      const frame = PoseFrame(
        poses: [],
        imageSize: Size(200, 100),
        rotation: InputImageRotation.rotation0deg,
        lensDirection: CameraLensDirection.back,
      );
      const canvasSize = Size(100, 100);

      final center = painter.mapPoint(const Offset(100, 50), frame, canvasSize);
      final leftEdge = painter.mapPoint(const Offset(0, 50), frame, canvasSize);
      final rightEdge = painter.mapPoint(const Offset(200, 50), frame, canvasSize);

      expect(center, const Offset(50, 50)); // image center -> canvas center
      expect(leftEdge.dx, -50); // cropped off-canvas to the left
      expect(rightEdge.dx, 150); // cropped off-canvas to the right
    });
  });

  group('shouldRepaint', () {
    test('false when frame and config are unchanged', () {
      const frame = PoseFrame(
        poses: [],
        imageSize: Size(100, 100),
        rotation: InputImageRotation.rotation0deg,
        lensDirection: CameraLensDirection.back,
      );
      final a = PoseOverlayPainter(frame: frame, config: config);
      final b = PoseOverlayPainter(frame: frame, config: config);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('true when confidenceThreshold changes', () {
      final a = PoseOverlayPainter(frame: null, config: config);
      final b = PoseOverlayPainter(
        frame: null,
        config: config.copyWith(confidenceThreshold: 0.9),
      );
      expect(a.shouldRepaint(b), isTrue);
    });
  });
}
