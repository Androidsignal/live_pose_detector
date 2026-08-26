[![pub package](https://img.shields.io/pub/v/live_pose_detector.svg)](https://pub.dev/packages/live_pose_detector)
[![likes](https://img.shields.io/pub/likes/live_pose_detector)](https://pub.dev/packages/live_pose_detector/score)
[![points](https://img.shields.io/pub/points/live_pose_detector)](https://pub.dev/packages/live_pose_detector/score)

# live_pose_detector

Real-time human pose detection with a skeleton overlay, plus a built-in push-up form checker and rep counter — one Dart API, no platform-channel code, no permission boilerplate.

Live camera feed + on-device ML Kit pose landmarks (33 keypoints) + a `CustomPainter` skeleton, all owned by `CameraPoseView`. `PushUpFormDetector` + `PushUpFeedbackBanner` build real-time posture feedback and rep counting on top of the same landmark stream — no extra detection work.

Requires Flutter >= 3.0, Dart >= 3.0, Android minSdk 21+, iOS 13+.

| Platform | Supported | Why |
|---|---|---|
| Android | ✅ | |
| iOS | ✅ | |
| macOS / Windows / Linux / Web | ❌ | `google_mlkit_pose_detection` (the on-device ML backend this package uses) only ships Android + iOS native implementations. No workaround at the permission or camera layer — the detector itself doesn't exist on those platforms. |

## Install

```yaml
dependencies:
  live_pose_detector: ^0.0.1
```

```
flutter pub get
```

## Quick start

```dart
import 'package:live_pose_detector/live_pose_detector.dart';

Scaffold(
  body: CameraPoseView(),
)
```

That's the whole integration — permission, camera, and skeleton rendering are all inside `CameraPoseView`. Hook `onPosesDetected` for your own logic (rep counting, angle checks, gesture triggers) off the same landmark stream, no extra detection:

```dart
CameraPoseView(
  initialLensDirection: CameraLensDirection.back,
  config: const PoseOverlayConfig(
    dotColor: Colors.greenAccent,
    lineColor: Colors.yellowAccent,
    confidenceThreshold: 0.5,
  ),
  onPosesDetected: (poses) {
    // Optional: run your own logic off the same landmark stream.
  },
  onError: (error) {
    // Optional: camera/detector init failed. If unset, the widget shows a
    // built-in error view with Retry (and Open Settings, if permanently
    // denied) instead.
  },
)
```

> **Want push-up form checking and rep counting?** See the [Push-up form detection](#push-up-form-detection--feedback) section below — it's a second widget/detector pair (`PushUpFormDetector` + `PushUpFeedbackBanner`) built on the exact same `onPosesDetected` stream, not a separate integration.

## `PoseOverlayConfig` reference

| Field | Type | Default | Description |
|---|---|---|---|
| `dotColor` | `Color` | `Colors.greenAccent` | Landmark dot color |
| `lineColor` | `Color` | `Colors.yellowAccent` | Skeleton line color |
| `dotRadius` | `double` | `5` | Landmark dot radius (logical px) |
| `lineWidth` | `double` | `3` | Skeleton line stroke width (logical px) |
| `confidenceThreshold` | `double` | `0.5` | Landmarks below this `likelihood` are hidden (dots and line endpoints) |
| `connections` | `List<List<PoseLandmarkType>>` | `kPoseConnections` | Skeleton topology — override to drop face points, add a custom subset, etc. |
| `resolutionPreset` | `ResolutionPreset` | `ResolutionPreset.medium` | Camera capture quality — balances landmark accuracy vs inference speed |
| `showCameraSwitchButton` | `bool` | `true` | Built-in front/back switch FAB. Set `false` to render your own control and call the state's `switchCamera()` |
| `detectionModel` | `PoseDetectionModel` | `PoseDetectionModel.accurate` | ML Kit model quality. `accurate` gives more precise landmarks at higher inference cost; `base` trades precision for speed |
| `haloColor` | `Color` | `Colors.black45` | Semi-transparent outline drawn under dots/lines so the skeleton stays legible over any background. `Colors.transparent` disables it |
| `requestCameraPermission` | `bool` | `true` | `CameraPoseView` requests camera permission itself before starting. Set `false` if your app already handles permission and wants to skip the extra request |

## Push-up form detection & feedback

```dart
final _detector = PushUpFormDetector();
final _feedback = ValueNotifier<PushUpFeedback?>(null);

CameraPoseView(
  onPosesDetected: (poses) => _feedback.value = _detector.evaluate(poses),
),
ValueListenableBuilder<PushUpFeedback?>(
  valueListenable: _feedback,
  builder: (context, feedback, _) => PushUpFeedbackBanner(feedback: feedback),
),
```

Use a `ValueNotifier` (not `setState`) — `onPosesDetected` fires on every frame, and `setState` there would rebuild the whole camera preview per frame instead of just the banner.

Every state `PushUpFormDetector.evaluate` can return, its message, and its color:

| `PushUpState` | Message | Color |
|---|---|---|
| `startingPosition` | Get into the push-up position. | neutral |
| `correctStartingPosition` | Great! You're in the correct position. | success |
| `bodyTooHigh` | Lower your hips and keep your body straight. | warning |
| `bodyTooLow` | Raise your hips slightly and keep your body aligned. | warning |
| `headTooLow` | Keep your head aligned with your body. | warning |
| `headTooHigh` | Keep your neck neutral and look slightly forward. | warning |
| `elbowsTooWide` | Keep your elbows closer to your body. | warning |
| `elbowsTooClose` | Adjust your elbows slightly outward for a comfortable position. | warning |
| `backNotStraight` | Keep your back straight and maintain a strong core. | warning |
| `notGoingLowEnough` | Lower your body further to complete the push-up. | warning |
| `goingTooLow` | Don't lower too far. Maintain a controlled range of motion. | warning |
| `correctDownwardMovement` | Good! Keep lowering with control. | success |
| `correctBottomPosition` | Great depth! Now push back up. | success |
| `correctUpwardMovement` | Good push! Keep your body straight. | success |
| `correctPushUpCompleted` | Perfect push-up! Keep going. | success |
| `movementTooFast` | Slow down and perform the movement with control. | warning |
| `incompletePushUp` | Complete the full movement from top to bottom. | warning |
| `wrongBodyAlignment` | Align your head, shoulders, hips, and legs. | warning |
| `correctFormMaintained` | Excellent form! Keep it up. | success |
| `noMovementDetected` | Start your push-up when you're ready. | neutral |

Only one is ever shown at a time, picked safety-first: **spine (back straightness) > neck > elbows > depth safety > tempo > insufficient depth > leg alignment > rep summary.** Static lookups without running a frame: `PushUpFormDetector.messageFor(state)` / `PushUpFormDetector.colorFor(state)`.

**Rep counting** requires the full correct cycle — correct starting position → controlled descent → correct depth → controlled ascent → correct top position — with no form issue anywhere in between. Any issue along the way still finishes the phase cycle but reports `incompletePushUp` instead of incrementing `PushUpFeedback.repCount`.

### Why it doesn't just compare raw angles to fixed thresholds

A single 2D camera measuring a straight body line against fixed absolute thresholds is fragile: camera angle, body proportions, and landmark noise (worst exactly when the body is moving fastest, mid-rep) all shift what "straight" reads as.

- **Auto-calibration** — the first few frames spent holding a genuinely stable top position establish this user's neutral hip/head/knee baseline; every check afterward measures deviation from that baseline, not an assumed universal zero. Requires several *consecutive* stable readings, not just the first few chronologically — an unstable window (still settling into position) restarts calibration instead of locking in bad data.
- **Depth-adaptive tolerance** — a side-on 2D camera reads more hip/head deviation than actually exists as the torso foreshortens with a bent elbow; tolerance widens smoothly from top to bottom of a rep so a correct deep rep doesn't read as worse form for being deeper.
- **Debounce** — a posture issue (back/head/elbow/knee) has to be the top-priority issue for a sustained stretch (`PushUpThresholds.minWarningPersistence`, default 200ms) before it's shown, so one noisy frame mid-descent doesn't flash a warning. Depth/tempo/rep-summary feedback stays instant — those are discrete events, not sustained conditions.
- **Body-orientation gate** — elbow angle alone can't tell a prone push-up from someone standing and bending their arm. The calibrated shoulder→ankle line angle is also tracked; if the body rotates too far from that orientation (`PushUpThresholds.maxBodyRotationDegrees`, default 45°) — stood up, turned around, walked off — rep logic stops entirely instead of counting nonsense reps.
- **Confidence gating** — a side (left/right) with unreliable landmarks (occlusion, motion blur) is treated as "no person" rather than judged.

### Tuning for your camera setup

Every threshold is overridable via `PushUpThresholds`:

```dart
PushUpFormDetector(
  thresholds: const PushUpThresholds(
    minLandmarkConfidence: 0.6,
    minWarningPersistence: Duration(milliseconds: 300),
    invertBodyLineSign: true, // flip if a correct rep reads as the opposite direction
  ),
)
```

`PushUpFeedback.debug` (a `PushUpDebugInfo`) exposes the raw numbers behind every judgment — smoothed elbow/abduction angles, calibrated hip/head/knee deviations, whether calibration has completed:

```dart
onPosesDetected: (poses) {
  final feedback = _detector.evaluate(poses);
  final debug = feedback.debug;
  if (debug != null) {
    debugPrint('elbow ${debug.elbowAngle} hip ${debug.hipDeviation} head ${debug.headDeviation}');
  }
  _feedback.value = feedback;
},
```

`PushUpFeedbackBanner` is configurable too — colors, text color, whether to show the rep chip, animation duration, margin. See its dartdoc for the full list.

## Building your own derived features

`onPosesDetected` fires with every detected frame's `List<Pose>` (ML Kit's own types — no custom pose model layer). Two bundled geometry helpers cover most rep-counting/gesture-trigger needs without forking the package or re-running detection:

- `angleBetweenLandmarks(a, center, b)` — the vertex angle (degrees) at `center` between rays to `a` and `b`. Use for elbow/knee bend angles.
- `signedLineDeviation` / `signedLandmarkLineDeviation` — signed perpendicular distance of a point from a line, normalized by the line's length. Use for straight-line-alignment checks (a plank/back-straightness check, for example) where a single unsigned angle can't tell which *side* a point has drifted to.

```dart
onPosesDetected: (poses) {
  if (poses.isEmpty) return;
  final landmarks = poses.first.landmarks;
  final shoulder = landmarks[PoseLandmarkType.leftShoulder];
  final elbow = landmarks[PoseLandmarkType.leftElbow];
  final wrist = landmarks[PoseLandmarkType.leftWrist];
  if (shoulder == null || elbow == null || wrist == null) return;
  final angle = angleBetweenLandmarks(shoulder, elbow, wrist);
},
```

See `example/lib/pose_demo_screen.dart` for both `CameraPoseView` and `PushUpFormDetector` wired to a real screen.

## ⚙️ Setup (required)

Add these to **your app**, not this package — it can't do it for you.

**1. `ios/Runner/Info.plist`:**

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to detect body pose.</string>
```

**2. `ios/Podfile`** — deployment target 13.0+:

```ruby
platform :ios, '13.0'
```

**3. `android/app/src/main/AndroidManifest.xml`:**

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**4. `android/app/build.gradle`** — `minSdkVersion` 21+.

Missing any of these means the camera either fails to start or the permission dialog never appears — no separate permission-request step needed beyond this; `CameraPoseView` handles the runtime request itself.

## Troubleshooting

**Skeleton/landmarks look mirrored or offset from the video** — should not happen; `PoseOverlayPainter.mapPoint` is unit-tested against ML Kit's actual per-rotation, per-platform coordinate behavior. If you see it, please file an issue with device/orientation/lens details rather than patching around it locally.

**Push-up feedback stuck on "Get into the push-up position"** — either no person is detected (check lighting/framing), landmark confidence is below `PushUpThresholds.minLandmarkConfidence`, or the body-orientation gate has kicked in because the tracked body angle drifted more than `maxBodyRotationDegrees` from its calibrated reference (e.g. you're not actually in a horizontal plank-like position, or the camera moved).

**A correct rep still shows a warning, or a bad rep shows green** — almost always a camera-setup issue, not a logic bug: place the camera side-on to the body, roughly level with hip height, far enough back to keep the whole body in frame through the full range of motion, and hold a genuinely straight top position for ~1 second before starting reps so calibration locks onto good data. If it's still off after that, check `PushUpFeedback.debug` — if one axis (hip/head/knee) is consistently biased in one direction regardless of posture, try `PushUpThresholds.invertBodyLineSign: true`.

**Warnings feel delayed** — intentional (`minWarningPersistence`, default 200ms) — absorbs single-frame landmark jitter, which is worst exactly when the body is moving fastest. Lower it if you want faster (but noisier) feedback.

## Known limitations

- **No macOS/Windows/Linux/Web support** — see the platform table above.
- **No widget test requires real camera hardware** — the camera plugin isn't stubbed for CI, so integration testing against a live camera is a manual/device step.
- **Push-up detection assumes one continuous, roughly side-on camera view per set.** It's not designed to handle mid-set camera cuts, angle changes, or footage of someone other than the person who calibrated (the body-orientation gate will reject those as "not in position," by design — see Troubleshooting).
- **Calibration assumes the user starts each set in a genuinely correct position.** If the very first stable frames aren't actually correct, the baseline will be off for that whole set; call `PushUpFormDetector.reset()` between sets.

## Example

Run `example/` — a Start screen (front/back picker) leading into a full-screen pose view: `CameraPoseView` handles permission, camera, and skeleton rendering; the built-in FAB toggles front/back (mirroring correctness visible immediately on switch); `onPosesDetected` is wired to `PushUpFormDetector`, and `PushUpFeedbackBanner` renders the live push-up feedback and rep count.

## Bugs & Credits

Report bugs and ask questions on [GitHub Issues](https://github.com/your-org/live_pose_detector/issues).
