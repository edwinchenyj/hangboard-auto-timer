# Platform Channel Contract

## Overview

The Hangboard Auto Timer uses Flutter platform channels to communicate between
Dart and native Android (Kotlin) / iOS (Swift) code for real-time pose
detection via MediaPipe.

## Channel Names

| Channel Type   | Name                                    | Purpose                      |
| -------------- | --------------------------------------- | ---------------------------- |
| MethodChannel  | `com.hangboard.auto_timer/pose`         | Start/stop pose detection    |
| EventChannel   | `com.hangboard.auto_timer/pose_events`  | Stream of gesture events     |

## MethodChannel API

### `start`

Starts the pose detection pipeline.

**Arguments:**

```json
{
  "frontCamera": true
}
```

| Field         | Type   | Required | Default | Description                        |
| ------------- | ------ | -------- | ------- | ---------------------------------- |
| `frontCamera` | `bool` | No       | `true`  | Use front-facing camera if `true`. |

**Returns:** `null` on success, throws `PlatformException` on failure.

### `stop`

Stops the pose detection pipeline and releases camera/ML resources.

**Arguments:** none

**Returns:** `null` on success.

## EventChannel API

### `com.hangboard.auto_timer/pose_events`

Emits a stream of gesture event maps whenever the pose detector classifies a
new frame.

### GestureEvent Payload

```json
{
  "tMs": 1706900000000,
  "gesture": "ARMS_UP",
  "confidence": 0.92
}
```

| Field        | Type     | Required | Description                                      |
| ------------ | -------- | -------- | ------------------------------------------------ |
| `tMs`        | `int`    | Yes      | Monotonic timestamp in milliseconds.              |
| `gesture`    | `String` | Yes      | One of `"ARMS_UP"`, `"ARMS_DOWN"`, `"UNKNOWN"`.  |
| `confidence` | `double` | No       | Detection confidence in [0, 1]. May be absent.    |

### Gesture Values

- **`ARMS_UP`** — Both wrists are detected above both shoulders (within margin).
  Indicates the user is hanging on the board.
- **`ARMS_DOWN`** — Both wrists are detected below both shoulders (within
  margin). Indicates the user is resting.
- **`UNKNOWN`** — Pose landmarks are not visible or confidence is too low to
  classify.

## Native Implementation Notes

### Frame Processing

- Process frames on a background thread/queue.
- Drop frames when the previous frame is still being processed (no backlog).
- Target ~15-30 fps for MediaPipe Pose Lite.

### Error Handling

- If the camera fails to start, send a `PlatformException` with code
  `"CAMERA_ERROR"`.
- If MediaPipe fails to initialize, send a `PlatformException` with code
  `"ML_INIT_ERROR"`.

### Lifecycle

- Native code must release camera and ML resources when `stop` is called.
- On Android, respect `Activity` lifecycle (pause/resume).
- On iOS, handle `AVCaptureSession` interruptions gracefully.
