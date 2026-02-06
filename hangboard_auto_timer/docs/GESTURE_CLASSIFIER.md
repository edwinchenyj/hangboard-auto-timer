# Gesture Classifier and Smoothing Specification

## Overview

Both Android (Kotlin) and iOS (Swift) implementations must follow this
specification to ensure consistent behavior across platforms.

The classifier takes raw MediaPipe Pose landmarks and produces a
`GestureEvent` with one of three gesture types: `ARMS_UP`, `ARMS_DOWN`, or
`UNKNOWN`.

## Landmarks Used

| Landmark         | MediaPipe Index | Purpose                    |
| ---------------- | --------------- | -------------------------- |
| Left Shoulder    | 11              | Reference for arm position |
| Right Shoulder   | 12              | Reference for arm position |
| Left Wrist       | 15              | Arm endpoint               |
| Right Wrist      | 16              | Arm endpoint               |

All coordinates are **normalized** to [0, 1] relative to image dimensions.
Y-axis: 0 = top of image, 1 = bottom.

## Classification Rules

### ARMS_UP

Both wrists must be **above** (lower Y value) both shoulders, accounting for
a vertical margin:

```
leftWrist.y  < leftShoulder.y  - MARGIN_Y
rightWrist.y < rightShoulder.y - MARGIN_Y
```

### ARMS_DOWN

Both wrists must be **below** (higher Y value) both shoulders, accounting for
a vertical margin:

```
leftWrist.y  > leftShoulder.y  + MARGIN_Y
rightWrist.y > rightShoulder.y + MARGIN_Y
```

### UNKNOWN

Any other configuration, or when landmark confidence is below threshold.

## Parameters

| Parameter         | Default Value | Description                                           |
| ----------------- | ------------- | ----------------------------------------------------- |
| `MARGIN_Y`        | `0.05`        | Normalized vertical margin for classification.        |
| `CONF_MIN`        | `0.5`         | Minimum landmark visibility/confidence to classify.   |
| `EMA_ALPHA`       | `0.3`         | Exponential moving average smoothing factor.          |
| `UP_HOLD_MS`      | `500`         | Arms-up must be sustained for this long to confirm.   |
| `DOWN_HOLD_MS`    | `300`         | Arms-down must be sustained for this long to confirm. |
| `STOP_IGNORE_MS`  | `1000`        | After entering HANG, ignore arms-down for this long.  |

## Confidence Threshold

Before classification, check that all four landmarks have visibility ≥
`CONF_MIN`. If any landmark is below threshold, emit `UNKNOWN`.

```
if (leftShoulder.visibility < CONF_MIN ||
    rightShoulder.visibility < CONF_MIN ||
    leftWrist.visibility < CONF_MIN ||
    rightWrist.visibility < CONF_MIN) {
  return UNKNOWN;
}
```

## EMA Smoothing

Apply exponential moving average to the Y-coordinates of all four landmarks
**before** classification to reduce noise:

```
smoothed_y = EMA_ALPHA * raw_y + (1 - EMA_ALPHA) * previous_smoothed_y
```

- `EMA_ALPHA = 0.3` — Higher values are more responsive but noisier.
- Initialize `previous_smoothed_y` to the first raw value.
- Apply independently to each landmark's Y coordinate.

### Why EMA?

Camera pose estimation is inherently noisy. Raw landmark positions can
fluctuate frame-to-frame even when the user is stationary. EMA provides
low-latency smoothing that reduces false transitions without introducing
significant delay.

## Hold-to-Confirm Logic

The raw classifier output is further processed by the `HangController` in
Dart, which requires **sustained** gesture detection before acting:

### Arms-Up Hold (`UP_HOLD_MS = 500ms`)

The gesture must consistently report `ARMS_UP` for at least 500ms before
the controller transitions from REST → PREP. If any non-`ARMS_UP` event
is received during this window, the hold timer resets.

### Arms-Down Hold (`DOWN_HOLD_MS = 300ms`)

The gesture must consistently report `ARMS_DOWN` for at least 300ms before
the controller transitions from HANG → REST. If any non-`ARMS_DOWN` event
is received, the hold timer resets.

### Rationale

- **UP_HOLD_MS (500ms)** is longer because accidentally starting a hang
  cycle is more disruptive than a slight delay to begin.
- **DOWN_HOLD_MS (300ms)** is shorter because the user wants quick feedback
  when they let go of the hangboard.

## STOP_IGNORE_MS Semantics

After the controller enters the `HANG` state, all `ARMS_DOWN` events are
**ignored** for `STOP_IGNORE_MS` milliseconds (default: 1000ms).

### Why?

When a climber first grabs the hangboard, their body may swing and momentarily
cause the wrists to dip below the shoulders. The stop-ignore window prevents
these false positives from ending the hang prematurely.

### Implementation

```dart
if (state == HANG && elapsedSinceHangStart < STOP_IGNORE_MS) {
  // Discard ARMS_DOWN events
  return;
}
```

## End-to-End Pipeline

```
Camera Frame
    ↓
MediaPipe Pose (native)
    ↓
Extract landmarks (shoulders + wrists)
    ↓
Check confidence ≥ CONF_MIN
    ↓
Apply EMA smoothing to Y coords
    ↓
Classify: ARMS_UP / ARMS_DOWN / UNKNOWN
    ↓
Emit GestureEvent via EventChannel
    ↓
HangController (Dart)
  - Hold-to-confirm (UP_HOLD_MS / DOWN_HOLD_MS)
  - Stop-ignore window (STOP_IGNORE_MS)
  - State transitions: REST ↔ PREP → HANG → REST
    ↓
UI Update
```

## Tuning Recommendations

| Scenario                        | Adjustment                                 |
| ------------------------------- | ------------------------------------------ |
| Too many false ARMS_UP          | Increase `MARGIN_Y` or `UP_HOLD_MS`        |
| Slow to recognize arms up       | Decrease `UP_HOLD_MS` or `MARGIN_Y`        |
| Hang ends too quickly           | Increase `STOP_IGNORE_MS` or `DOWN_HOLD_MS`|
| Noisy/jittery classification    | Decrease `EMA_ALPHA` (more smoothing)       |
| Sluggish/laggy response         | Increase `EMA_ALPHA` (less smoothing)       |
| Missing landmarks in dim light  | Decrease `CONF_MIN` (accept lower quality)  |
