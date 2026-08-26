## 0.0.1

Initial release.

**Pose detection & skeleton overlay**

- `CameraPoseView` — turnkey pose-tracking widget. Live camera feed + on-device ML Kit pose detection (stream mode) + `CustomPainter` skeleton overlay, all owned internally (camera capture, permission, detection, rendering).
- Front/back camera switching with correct selfie mirroring — preview and skeleton mirror together as one unit via a single `Transform`, so they never desync.
- `PoseOverlayPainter.mapPoint` matches `BoxFit.cover`'s exact scale-and-crop math and ML Kit's real per-rotation, per-platform coordinate behavior (verified against the official `google_mlkit_pose_detection` example) — unit-tested for all four rotations on both Android and iOS.
- Confidence-gated rendering via `PoseOverlayConfig.confidenceThreshold`; customizable skeleton topology via `PoseOverlayConfig.connections` (defaults to `kPoseConnections`).
- `CameraPoseView` requests camera permission itself before starting — no separate permission step needed in host apps. `CameraPermissionDeniedException` surfaces through `onError` (or the built-in error view, which shows "Open Settings" when permanently denied). Opt out with `PoseOverlayConfig.requestCameraPermission: false`.
- `onPosesDetected` passthrough for host app logic — no extra detection work, same landmark stream the painter uses.
- Per-frame skeleton updates go through a `ValueNotifier` + `ValueListenableBuilder` scoped to just the `CustomPaint`, not `setState` on the whole widget — avoids rebuilding the camera preview every frame.
- Geometry helpers exported for building derived features: `angleBetweenLandmarks(a, center, b)` (vertex angle for joint-bend checks) and `signedLineDeviation` / `signedLandmarkLineDeviation` (signed perpendicular line-deviation, for straight-line-alignment checks a plain vertex angle can't disambiguate).

**Push-up form detection & feedback**

- `PushUpFormDetector` + `PushUpFeedbackBanner` — a full push-up form checker and rep counter built entirely on `onPosesDetected`, no forked internals. Detects 20 distinct states (correct start/depth/completion, back/head/elbow/knee posture issues, tempo and depth safety issues) with a fixed safety-first priority order — only one message is ever shown. `PushUpThresholds` exposes every angle/deviation/timing threshold for tuning to a real camera setup; `PushUpFeedback.debug` (`PushUpDebugInfo`) exposes the raw numbers behind every judgment.
- Auto-calibrates each user's own neutral hip/head/knee baseline from a stable top-position hold (requires *consecutive* stable readings, not just the first few chronologically — an unstable window restarts calibration instead of locking in bad data).
- Depth-adaptive tolerance compensates for 2D-camera foreshortening at the bottom of a rep.
- Debounces posture warnings (`minWarningPersistence`, default 200ms) so single-frame landmark jitter mid-rep doesn't flash a false warning; depth/tempo/rep-summary feedback stays instant.
- Body-orientation gate: tracks the calibrated shoulder→ankle line angle and stops rep logic entirely if the body rotates too far from it (e.g. the person stood up) — elbow angle alone can't otherwise distinguish a prone push-up from a standing arm-bend.
- Rep counting requires the full correct cycle — correct starting position → controlled descent → correct depth → controlled ascent → correct top position, with no form issue anywhere in between — otherwise it's reported "Incomplete Push-Up" and not counted.
