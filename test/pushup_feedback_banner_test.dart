import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_pose_detector/live_pose_detector.dart';

void main() {
  Widget host(PushUpFeedback? feedback) => MaterialApp(
      home: Scaffold(body: PushUpFeedbackBanner(feedback: feedback)));

  testWidgets('renders nothing when feedback is null', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.byType(PushUpFeedbackBanner), findsOneWidget);
    expect(find.text('Reps: 0'), findsNothing);
  });

  testWidgets('shows message, rep count, and success color', (tester) async {
    const feedback = PushUpFeedback(
      state: PushUpState.correctPushUpCompleted,
      message: 'Perfect push-up! Keep going.',
      color: PushUpFeedbackColor.success,
      repCount: 3,
      phase: PushUpPhase.ready,
    );
    await tester.pumpWidget(host(feedback));
    await tester.pumpAndSettle();

    expect(find.text('Perfect push-up! Keep going.'), findsOneWidget);
    expect(find.text('Reps: 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows warning icon for warning feedback', (tester) async {
    const feedback = PushUpFeedback(
      state: PushUpState.goingTooLow,
      message: "Don't lower too far. Maintain a controlled range of motion.",
      color: PushUpFeedbackColor.warning,
      repCount: 0,
      phase: PushUpPhase.bottom,
    );
    await tester.pumpWidget(host(feedback));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('hides the rep chip when showRepCount is false', (tester) async {
    const feedback = PushUpFeedback(
      state: PushUpState.startingPosition,
      message: 'Get into the push-up position.',
      color: PushUpFeedbackColor.neutral,
      repCount: 0,
      phase: PushUpPhase.idle,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
            body:
                PushUpFeedbackBanner(feedback: feedback, showRepCount: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Reps:'), findsNothing);
    expect(find.text('Get into the push-up position.'), findsOneWidget);
  });

  testWidgets('crossfades the message when the state changes', (tester) async {
    const first = PushUpFeedback(
      state: PushUpState.correctDownwardMovement,
      message: 'Good! Keep lowering with control.',
      color: PushUpFeedbackColor.success,
      repCount: 0,
      phase: PushUpPhase.descending,
    );
    const second = PushUpFeedback(
      state: PushUpState.backNotStraight,
      message: 'Keep your back straight and maintain a strong core.',
      color: PushUpFeedbackColor.warning,
      repCount: 0,
      phase: PushUpPhase.descending,
    );

    await tester.pumpWidget(host(first));
    await tester.pumpAndSettle();
    expect(find.text('Good! Keep lowering with control.'), findsOneWidget);

    await tester.pumpWidget(host(second));
    await tester.pump(); // mid-transition
    await tester.pumpAndSettle();

    expect(find.text('Keep your back straight and maintain a strong core.'),
        findsOneWidget);
    expect(find.text('Good! Keep lowering with control.'), findsNothing);
  });

  testWidgets('old and new messages are never visible at the same time',
      (tester) async {
    const first = PushUpFeedback(
      state: PushUpState.correctDownwardMovement,
      message: 'Good! Keep lowering with control.',
      color: PushUpFeedbackColor.success,
      repCount: 0,
      phase: PushUpPhase.descending,
    );
    const second = PushUpFeedback(
      state: PushUpState.backNotStraight,
      message: 'Keep your back straight and maintain a strong core.',
      color: PushUpFeedbackColor.warning,
      repCount: 0,
      phase: PushUpPhase.descending,
    );

    double opacityOf(String text) {
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
                of: find.text(text), matching: find.byType(FadeTransition))
            .first,
      );
      return fade.opacity.value;
    }

    await tester.pumpWidget(host(first));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(second));

    for (var ms = 0; ms <= 250; ms += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.text(first.message).evaluate().isEmpty) break;
      final oldOpacity = opacityOf(first.message);
      final newOpacity = opacityOf(second.message);
      expect(oldOpacity == 0 || newOpacity == 0, isTrue,
          reason: 'at ${ms}ms old=$oldOpacity new=$newOpacity');
    }
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });
}
