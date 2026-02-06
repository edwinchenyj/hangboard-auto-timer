import 'package:flutter_test/flutter_test.dart';
import 'package:hangboard_auto_timer/logic/hang_controller.dart';
import 'package:hangboard_auto_timer/pose/gesture_event.dart';

void main() {
  late HangController controller;
  late List<HangState> transitions;
  int baseTime = 1000000;

  int nextMs([int delta = 0]) {
    baseTime += delta;
    return baseTime;
  }

  int realNow() => DateTime.now().millisecondsSinceEpoch;

  GestureEvent armsUp(int tMs, {double confidence = 0.9}) => GestureEvent(
    tMs: tMs,
    gesture: GestureType.armsUp,
    confidence: confidence,
  );

  GestureEvent armsDown(int tMs, {double confidence = 0.9}) => GestureEvent(
    tMs: tMs,
    gesture: GestureType.armsDown,
    confidence: confidence,
  );

  GestureEvent unknown(int tMs) =>
      GestureEvent(tMs: tMs, gesture: GestureType.unknown, confidence: 0.5);

  setUp(() {
    baseTime = 1000000;
    transitions = [];
    controller = HangController(
      config: const HangConfig(
        prepMs: 3000,
        upHoldMs: 500,
        downHoldMs: 300,
        stopIgnoreMs: 1000,
        confMin: 0.5,
      ),
      onTransition: (from, to) => transitions.add(to),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('Initial state', () {
    test('starts in REST state', () {
      expect(controller.state, HangState.rest);
    });

    test('starts at set number 1', () {
      expect(controller.setNumber, 1);
    });
  });

  group('REST to PREP transition (arms-up hold)', () {
    test('transitions to PREP after sustained arms-up hold', () {
      controller.onGestureEvent(armsUp(nextMs()));
      expect(controller.state, HangState.rest);
      controller.onGestureEvent(armsUp(nextMs(600)));
      expect(controller.state, HangState.prep);
      expect(transitions, contains(HangState.prep));
    });

    test('does NOT transition if arms drop before hold threshold', () {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(200)));
      controller.onGestureEvent(armsDown(nextMs(100)));
      expect(controller.state, HangState.rest);
    });

    test('resets hold timer on arms-down during hold', () {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(400)));
      controller.onGestureEvent(armsDown(nextMs(50)));
      controller.onGestureEvent(armsUp(nextMs(50)));
      controller.onGestureEvent(armsUp(nextMs(400)));
      expect(controller.state, HangState.rest);
      controller.onGestureEvent(armsUp(nextMs(200)));
      expect(controller.state, HangState.prep);
    });
  });

  group('PREP cancel (arms drop)', () {
    test('cancels prep and returns to REST if arms drop during prep', () {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      expect(controller.state, HangState.prep);
      controller.onGestureEvent(armsDown(nextMs(100)));
      expect(controller.state, HangState.rest);
    });

    test('cancels prep on UNKNOWN gesture', () {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      expect(controller.state, HangState.prep);
      controller.onGestureEvent(unknown(nextMs(100)));
      expect(controller.state, HangState.rest);
    });
  });

  group('PREP to HANG (countdown)', () {
    test('transitions to HANG after prep countdown completes', () async {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      expect(controller.state, HangState.prep);
      await Future.delayed(const Duration(milliseconds: 3200));
      expect(controller.state, HangState.hang);
      expect(transitions, contains(HangState.hang));
    });
  });

  group('HANG to REST (arms-down hold with stop-ignore)', () {
    test('ignores arms-down within STOP_IGNORE_MS window', () async {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      await Future.delayed(const Duration(milliseconds: 3200));
      expect(controller.state, HangState.hang);

      // Use real timestamps since _hangStartMs is set from real clock
      final now = realNow();
      controller.onGestureEvent(armsDown(now + 100));
      controller.onGestureEvent(armsDown(now + 500));
      controller.onGestureEvent(armsDown(now + 900));
      expect(controller.state, HangState.hang);
    });

    test('transitions to REST after stop-ignore window + down hold', () async {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      await Future.delayed(const Duration(milliseconds: 3200));
      expect(controller.state, HangState.hang);

      final now = realNow();
      controller.onGestureEvent(armsDown(now + 1100));
      controller.onGestureEvent(armsDown(now + 1500));
      expect(controller.state, HangState.rest);
    });

    test(
      'does NOT transition if arms go back up before hold confirmed',
      () async {
        controller.onGestureEvent(armsUp(nextMs()));
        controller.onGestureEvent(armsUp(nextMs(600)));
        await Future.delayed(const Duration(milliseconds: 3200));
        expect(controller.state, HangState.hang);

        final now = realNow();
        controller.onGestureEvent(armsDown(now + 1100));
        controller.onGestureEvent(armsUp(now + 1200));
        expect(controller.state, HangState.hang);
      },
    );
  });

  group('Confidence filtering', () {
    test('ignores events below confidence threshold', () {
      controller.onGestureEvent(armsUp(nextMs(), confidence: 0.3));
      controller.onGestureEvent(armsUp(nextMs(600), confidence: 0.3));
      expect(controller.state, HangState.rest);
    });

    test('accepts events at or above confidence threshold', () {
      controller.onGestureEvent(armsUp(nextMs(), confidence: 0.5));
      controller.onGestureEvent(armsUp(nextMs(600), confidence: 0.5));
      expect(controller.state, HangState.prep);
    });
  });

  group('Set counter', () {
    test('increments set number after HANG to REST', () async {
      expect(controller.setNumber, 1);
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      await Future.delayed(const Duration(milliseconds: 3200));

      final now = realNow();
      controller.onGestureEvent(armsDown(now + 1100));
      controller.onGestureEvent(armsDown(now + 1500));
      expect(controller.state, HangState.rest);
      expect(controller.setNumber, 2);
    });
  });

  group('Reset', () {
    test('reset returns to initial state', () {
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      expect(controller.state, HangState.prep);
      controller.reset();
      expect(controller.state, HangState.rest);
      expect(controller.setNumber, 1);
    });
  });

  group('HangCompleted callback', () {
    test('fires callback with hang duration on HANG to REST', () async {
      int? reportedHangMs;
      controller.onHangCompleted = (hangMs, restMs) {
        reportedHangMs = hangMs;
      };

      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(600)));
      await Future.delayed(const Duration(milliseconds: 3200));

      final now = realNow();
      controller.onGestureEvent(armsDown(now + 1100));
      controller.onGestureEvent(armsDown(now + 1500));
      expect(reportedHangMs, isNotNull);
      expect(reportedHangMs!, greaterThan(0));
    });
  });

  group('Config update', () {
    test('new config takes effect immediately', () {
      controller.updateConfig(
        const HangConfig(
          upHoldMs: 100,
          prepMs: 1000,
          downHoldMs: 100,
          stopIgnoreMs: 500,
        ),
      );
      controller.onGestureEvent(armsUp(nextMs()));
      controller.onGestureEvent(armsUp(nextMs(150)));
      expect(controller.state, HangState.prep);
    });
  });
}
