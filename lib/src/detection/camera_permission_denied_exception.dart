import 'package:permission_handler/permission_handler.dart';

/// Thrown by [CameraPoseView] when camera permission isn't granted after
/// requesting it. Carries the resulting [PermissionStatus] so callers
/// (including the widget's own built-in error view) can tell a plain
/// "not granted yet" from "permanently denied — needs Settings".
class CameraPermissionDeniedException implements Exception {
  const CameraPermissionDeniedException(this.status);

  final PermissionStatus status;

  @override
  String toString() => 'CameraPermissionDeniedException($status)';
}
