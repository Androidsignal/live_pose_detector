[![dashstack_poster](https://github.com/user-attachments/assets/01150ab3-4631-48a2-8c56-5c64d0fd887b)](https://www.dashstack.tech/)

# live_pose_detector

Real-time pose detection with a skeleton overlay, plus a built-in push-up form checker and rep counter — one widget, no permission boilerplate, no platform-channel code.

`CameraPoseView` owns the camera, permission, ML Kit detection, and skeleton rendering. `PushUpFormDetector` + `PushUpFeedbackBanner` add posture feedback and rep counting on top of the same landmark stream.

Requires Flutter >= 3.0, Dart >= 3.0, Android minSdk 21+, iOS 13+.

| Platform | Supported |
|---|---|
| Android, iOS | ✅ |
| macOS, Windows, Linux, Web | ❌ — `google_mlkit_pose_detection` (the ML backend) only ships Android + iOS |

## Install

```yaml
dependencies:
  live_pose_detector: <latest_version>
```

## Quick start

```dart
import 'package:live_pose_detector/live_pose_detector.dart';

Scaffold(
  body: CameraPoseView(),
)
```

That's the whole integration. Add your own logic via `onPosesDetected`:

```dart
CameraPoseView(
  initialLensDirection: CameraLensDirection.back,
  config: const PoseOverlayConfig(dotColor: Colors.greenAccent),
  onPosesDetected: (poses) {
    // your logic — same landmark stream, no extra detection work
  },
  onError: (error) {
    // optional — defaults to a built-in error view with Retry
  },
)
```

## `PoseOverlayConfig` options

| Field | Default | Description |
|---|---|---|
| `dotColor` / `lineColor` | green / yellow | Skeleton colors |
| `dotRadius` / `lineWidth` | `5` / `3` | Skeleton sizing |
| `confidenceThreshold` | `0.5` | Hides landmarks below this likelihood |
| `connections` | `kPoseConnections` | Skeleton topology — override to customize |
| `resolutionPreset` | `medium` | Camera quality vs. speed |
| `detectionModel` | `accurate` | ML Kit model quality vs. speed |
| `showCameraSwitchButton` | `true` | Built-in front/back FAB |
| `requestCameraPermission` | `true` | Set `false` if you handle permission yourself |

## Push-up form detection

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

(Use a `ValueNotifier`, not `setState` — this fires every frame.)

`evaluate()` returns one `PushUpFeedback` per frame: a message, a color (`success` / `warning` / `neutral`), and the running rep count. Only one message is ever shown, picked safety-first: **spine > neck > elbows > depth safety > tempo > insufficient depth > leg alignment > rep summary.** Full list of states/messages/colors: `PushUpState` in `lib/src/pushup/pushup_types.dart`.

A rep only counts on a full correct cycle — top → controlled descent → correct depth → controlled ascent → top — with no form issue anywhere in between. Anything else finishes the cycle but reports `incompletePushUp` instead of counting.

**Why it's not just raw angles vs. fixed thresholds:** camera angle, body shape, and landmark noise all shift what "straight" looks like. So it:

- **Calibrates** each user's own neutral baseline from a genuinely stable top-position hold, not an assumed universal zero
- **Widens tolerance** near the bottom of a rep, since a 2D camera reads more deviation than actually exists as the torso foreshortens
- **Debounces** posture warnings (~200ms) so one noisy frame doesn't flash a false warning
- **Gates on body orientation** — if the body rotates away from the calibrated push-up angle (e.g. you stood up), rep tracking stops instead of counting nonsense

Every threshold is overridable via `PushUpThresholds`, and `PushUpFeedback.debug` exposes the raw numbers behind each judgment for tuning:

```dart
PushUpFormDetector(
  thresholds: const PushUpThresholds(minWarningPersistence: Duration(milliseconds: 300)),
)
```

## Building your own features

`onPosesDetected` gives you every frame's `List<Pose>` (ML Kit's own types). Two helpers cover most rep-counting/gesture logic:

- `angleBetweenLandmarks(a, center, b)` — joint angle at `center`, e.g. elbow bend
- `signedLineDeviation` / `signedLandmarkLineDeviation` — signed distance of a point from a line, for straight-line checks (back straightness) where a plain angle can't tell which side something drifted to

See `example/lib/pose_demo_screen.dart` for both features wired to a real screen.

## ⚙️ Setup (required)

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to detect body pose.</string>
```
Deployment target 13.0+ in `ios/Podfile`.

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```
`minSdkVersion` 21+ in `android/app/build.gradle`.

## Troubleshooting

**Skeleton looks mirrored or offset** — file an issue with device/orientation/lens details; this is unit-tested and shouldn't happen.

**Feedback stuck on "Get into the push-up position"** — no person detected, low landmark confidence, or the body-orientation gate tripped (you're not in a horizontal plank pose, or the camera moved).

**Correct rep shows a warning (or vice versa)** — camera setup, not a logic bug: go side-on, roughly hip height, whole body in frame, hold a straight top position for ~1s before starting. Still off? Check `PushUpFeedback.debug`; a consistent one-direction bias means try `PushUpThresholds.invertBodyLineSign: true`.

**Warnings feel delayed** — intentional (`minWarningPersistence`, default 200ms), filters landmark jitter. Lower it for faster but noisier feedback.

## Known limitations

- No macOS/Windows/Linux/Web (ML Kit backend doesn't support them)
- No CI coverage for a real camera device — manual testing only
- Push-up detection expects one continuous, side-on camera view per set — not multi-angle footage
- Calibration assumes you start each set in a correct position; call `PushUpFormDetector.reset()` between sets

## Example

Run `example/` — a Start screen (camera picker) into a full-screen pose view with push-up feedback and rep counting wired up end to end.

## Bugs & Credits

Report bugs and ask questions on [GitHub Issues](https://github.com/your-org/live_pose_detector/issues).
Maintained by [Dashstack Infotech, Surat](https://www.dashstack.tech/).
