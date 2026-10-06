import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:live_pose_detector/src/detection/input_image_converter.dart';

void main() {
  const converter = InputImageConverter();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('calculateRotation on iOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    for (final sensorOrientation in [0, 90, 180, 270]) {
      test('maps sensorOrientation $sensorOrientation directly', () {
        final rotation = converter.calculateRotation(
          sensorOrientation: sensorOrientation,
          lensDirection: CameraLensDirection.back,
          deviceOrientationDegrees: 0,
        );
        expect(
          rotation,
          InputImageRotationValue.fromRawValue(sensorOrientation),
        );
      });
    }
  });

  group('calculateRotation on Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('back camera subtracts device orientation from sensor orientation',
        () {
      final rotation = converter.calculateRotation(
        sensorOrientation: 90,
        lensDirection: CameraLensDirection.back,
        deviceOrientationDegrees: 0,
      );
      expect(rotation, InputImageRotationValue.fromRawValue(90));
    });

    test('front camera adds device orientation to sensor orientation', () {
      final rotation = converter.calculateRotation(
        sensorOrientation: 270,
        lensDirection: CameraLensDirection.front,
        deviceOrientationDegrees: 90,
      );
      expect(rotation, InputImageRotationValue.fromRawValue(0));
    });

    for (final sensorOrientation in [0, 90, 180, 270]) {
      test(
          'handles sensorOrientation $sensorOrientation with zero device rotation',
          () {
        final rotation = converter.calculateRotation(
          sensorOrientation: sensorOrientation,
          lensDirection: CameraLensDirection.back,
          deviceOrientationDegrees: 0,
        );
        expect(
          rotation,
          InputImageRotationValue.fromRawValue(sensorOrientation),
        );
      });
    }
  });
}
