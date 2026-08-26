import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Converts a [CameraImage] frame into an ML Kit [InputImage].
///
/// Byte-plane handling and rotation math differ between Android and iOS —
/// isolated here so it's independently unit-testable without a real camera.
class InputImageConverter {
  const InputImageConverter();

  /// Builds an [InputImage] from [image], or `null` if the combination of
  /// platform/format/orientation isn't supported (frame should be dropped).
  InputImage? convert({
    required CameraImage image,
    required CameraDescription cameraDescription,
    required int deviceOrientationDegrees,
  }) {
    final rotation = calculateRotation(
      sensorOrientation: cameraDescription.sensorOrientation,
      lensDirection: cameraDescription.lensDirection,
      deviceOrientationDegrees: deviceOrientationDegrees,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Android (NV21/YUV420 as delivered by the camera plugin) hands us
    // multiple planes that must be concatenated; iOS (BGRA8888) is a
    // single plane already in the right byte layout.
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (format != InputImageFormat.nv21 &&
          format != InputImageFormat.yv12) {
        return null;
      }
      final bytes = _concatenatePlanes(image.planes);
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (format != InputImageFormat.bgra8888) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    return null;
  }

  /// Maps sensor orientation + lens direction + current device orientation
  /// to ML Kit's [InputImageRotation], per the four possible
  /// `sensorOrientation` values (0/90/180/270).
  @visibleForTesting
  InputImageRotation? calculateRotation({
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
    required int deviceOrientationDegrees,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    // Android: combine sensor orientation with device (UI) orientation.
    // Front camera sensors are mirrored relative to back camera sensors.
    var rotationCompensation = deviceOrientationDegrees;
    if (lensDirection == CameraLensDirection.front) {
      rotationCompensation =
          (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final builder = BytesBuilder(copy: false);
    for (final plane in planes) {
      builder.add(plane.bytes);
    }
    return builder.toBytes();
  }
}
