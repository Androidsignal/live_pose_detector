## 0.0.2

- `PoseOverlayConfig.cameraSwitchButtonPosition` — place the built-in camera switch button in any corner (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`). The button now respects safe-area insets.
- Hide parts of the skeleton: `showFaceLandmarks`, `showFingerLandmarks`, `showLegLandmarks`, `showArmLandmarks`, `showTorsoLandmarks`, plus `hiddenLandmarks` for individual points. Lines touching a hidden point are hidden too.
- `PushUpFeedbackBanner`: the old and new messages no longer overlap during transitions, the icon changes together with the message, width animates smoothly, and a new `maxWidth` caps it on wide screens. Messages are announced to screen readers.

## 0.0.1

Initial release.

- `CameraPoseView` — live camera feed with a pose skeleton overlay, powered by ML Kit.
- `PushUpFormDetector` + `PushUpFeedbackBanner` — push-up form checker with real-time feedback and rep counting.
- Front/back camera switching, camera permission handling, and customizable skeleton styling built in.
