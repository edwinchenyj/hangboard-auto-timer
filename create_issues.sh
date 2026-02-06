#!/usr/bin/env bash
set -euo pipefail

create () {
  local title="$1"; shift
  local labels="$1"; shift
  local body="$1"; shift
  gh issue create --title "$title" --label "$labels" --body "$body"
}

create "Define MVP spec and acceptance checklist" \
"area:flutter,priority:p0" \
$'Write a short PRODUCT.md that defines:\n- REST→PREP→HANG state machine\n- Default params: UP_HOLD_MS=400, DOWN_HOLD_MS=400, PREP_MS=2000, STOP_IGNORE_MS=800, CONF_MIN=0.5\n- Manual acceptance tests (arms-up triggers prep; prep->hang; arms-down ends hang; no false stop in first 0.8s)\n\nDeliverable:\n- PRODUCT.md committed to repo.'

create "Flutter app architecture skeleton (folders + interfaces)" \
"area:flutter,priority:p0" \
$'Implement stubs (no ML yet):\n- lib/pose/pose_service.dart (abstract + platform channel wrapper)\n- lib/logic/hang_controller.dart (state machine)\n- lib/ui/training_screen.dart (placeholder UI)\n- lib/storage/session_store.dart (interface)\n\nDeliverable:\n- Compiles and runs showing placeholder UI + state machine driven by fake events.'

create "Implement HangController state machine + timers" \
"area:flutter,priority:p0" \
$'Implement a robust REST/PREP/HANG controller:\n- Hold-to-confirm for ARMS_UP/DOWN using monotonic timestamps\n- Prep countdown (configurable)\n- STOP_IGNORE_MS after entering HANG\n- Expose UiState (state, hangMs, restMs, prepRemainingMs)\n\nAdd unit tests for transitions.\n\nDeliverable:\n- Unit tests covering edge cases (cancel prep if arms drop; require sustained holds; ignore stop early).'

create "Training screen UI (large timers, state colors, beeps/haptics)" \
"area:flutter,priority:p0" \
$'Build TrainingScreen with distance-readable UI:\n- Big primary display: REST/PREP/HANG\n- Smaller secondary timer if needed\n- State indicator + color change per state\n- Beep/haptic on PREP→HANG and HANG→REST\n\nDeliverable:\n- Screen works with injected fake gesture stream.'

create "Platform channel contract for gesture events" \
"area:flutter,priority:p0" \
$'Define platform channel API:\nDart methods:\n- start(frontCamera=true)\n- stop()\n- Stream<GestureEvent> gestureEvents()\n\nGestureEvent payload:\n{ tMs: int, gesture: \"ARMS_UP\"|\"ARMS_DOWN\"|\"UNKNOWN\", confidence: double (optional) }\n\nDeliverable:\n- Document channel names + payload shapes in docs/PLATFORM_CHANNEL.md.'

create "Android native: integrate MediaPipe Pose and emit GestureEvents" \
"area:ml,priority:p0" \
$'Android (Kotlin):\n- Use MediaPipe Pose to extract shoulders + wrists + confidence\n- Classify gesture ARMS_UP/ARMS_DOWN/UNKNOWN using normalized coords and margin\n- Apply smoothing (EMA) and confidence threshold\n- Emit GestureEvents to Flutter stream\n- Ensure no frame backlog (drop frames when busy)\n\nDeliverable:\n- Works on a Pixel device; logs gesture events; wired to Flutter.'

create "iOS native: integrate MediaPipe Pose and emit GestureEvents" \
"area:ml,priority:p0" \
$'iOS (Swift):\n- Same behavior as Android for consistency\n- MediaPipe Pose integration\n- Same classifier + thresholds + smoothing\n- Emit GestureEvents to Flutter stream\n- Ensure no frame backlog\n\nDeliverable:\n- Runs on iPhone simulator/device; gesture events arrive in Flutter.'

create "Gesture classifier and smoothing spec (shared behavior doc)" \
"area:ml,priority:p0" \
$'Create docs/GESTURE_CLASSIFIER.md that defines:\n- Confidence threshold rules\n- MarginY and how it is applied\n- EMA smoothing parameters\n- Hold-to-confirm logic (UP_HOLD_MS, DOWN_HOLD_MS)\n- STOP_IGNORE_MS semantics\n\nDeliverable:\n- Document matches implementation on both platforms.'

create "Session logging + history screen (local persistence)" \
"area:flutter,priority:p1" \
$'Persist per-hang events locally:\n- timestamp\n- hang duration ms\n- rest duration ms\n- settings snapshot (optional)\n\nImplement HistoryScreen listing sessions/events.\n\nDeliverable:\n- Uses sqflite or local JSON; basic list UI.'

create "Settings screen for timing thresholds" \
"area:flutter,priority:p1" \
$'Add a settings screen:\n- PREP_MS\n- UP_HOLD_MS / DOWN_HOLD_MS\n- STOP_IGNORE_MS\n- CONF_MIN (optional)\n- Save locally\n\nDeliverable:\n- Settings persist and affect controller behavior.'

create "Add CI: Flutter analyze + test on PRs" \
"area:infra,priority:p1" \
$'Add GitHub Actions workflow:\n- flutter format (optional)\n- flutter analyze\n- flutter test\n\nDeliverable:\n- .github/workflows/ci.yml.'

create "Add a debug overlay (optional) showing detected arms state/confidence" \
"area:flutter,priority:p1" \
$'Optional debug UI:\n- Display latest gesture + confidence\n- Show whether hold timer is satisfied\n- Toggle in settings\n\nDeliverable:\n- Helps tune thresholds in real-world use.'
