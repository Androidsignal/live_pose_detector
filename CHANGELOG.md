## 0.0.4

- Fixed `CameraException(Disposed CameraController, buildPreview() was called on a disposed CameraController.)` when the app went to the background, a system overlay appeared, or the camera was switched.
- The camera is now released only when the app is truly backgrounded (`paused`), not on `inactive` (notification shade, screenshots, system dialogs).
- Added screenshots to the pubspec so pub.dev shows a package thumbnail.
- Updated dependencies: `camera` ^0.12.1, `google_mlkit_pose_detection` ^0.16.1, `permission_handler` ^13.0.2.

## 0.0.3

- README: added screenshots of the skeleton overlay on push-ups, squats, lateral raises, jumping jacks, and lunges.

## 0.0.2

- `PoseOverlayConfig.cameraSwitchButtonPosition` — place the built-in camera switch button in any corner (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`). The button now respects safe-area insets.
- Hide parts of the skeleton: `showFaceLandmarks`, `showFingerLandmarks`, `showLegLandmarks`, `showArmLandmarks`, `showTorsoLandmarks`, plus `hiddenLandmarks` for individual points. Lines touching a hidden point are hidden too.
- `PushUpFeedbackBanner`: the old and new messages no longer overlap during transitions, the icon changes together with the message, width animates smoothly, and a new `maxWidth` caps it on wide screens. Messages are announced to screen readers.

## 0.0.1

Initial release.

- `CameraPoseView` — live camera feed with a pose skeleton overlay, powered by ML Kit.
- `PushUpFormDetector` + `PushUpFeedbackBanner` — push-up form checker with real-time feedback and rep counting.
- Front/back camera switching, camera permission handling, and customizable skeleton styling built in.
