# Hangboard Auto Timer - MVP Product Specification

## Overview
The Hangboard Auto Timer is an application that automatically times hangboard training sessions using pose detection. The app transitions through states based on the user's arm position, eliminating the need for manual timer controls.

## State Machine

The application follows a simple three-state machine:

```
REST → PREP → HANG → REST
```

### State Definitions

1. **REST**: Initial/idle state
   - User is not in position
   - Timer is not active
   - Waiting for user to raise arms to begin

2. **PREP**: Preparation state
   - Triggered when user raises arms above their head
   - Countdown timer begins (default: 2 seconds)
   - User prepares to grip the hangboard
   - Transitions to HANG when countdown completes

3. **HANG**: Active hanging state
   - User is hanging on the hangboard
   - Main workout timer is active
   - Ends when user lowers arms (releases grip and drops down)
   - Has a grace period to prevent false stops

### State Transitions

- **REST → PREP**: Arms raised above head (detected for UP_HOLD_MS duration)
- **PREP → HANG**: Preparation countdown completes (PREP_MS elapsed)
- **HANG → REST**: Arms lowered (detected for DOWN_HOLD_MS duration, after STOP_IGNORE_MS grace period)

## Default Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `UP_HOLD_MS` | 400 | Milliseconds to hold arms up before triggering PREP state |
| `DOWN_HOLD_MS` | 400 | Milliseconds to hold arms down before ending HANG state |
| `PREP_MS` | 2000 | Preparation countdown duration in milliseconds (2 seconds) |
| `STOP_IGNORE_MS` | 800 | Grace period at start of HANG to ignore false stops (milliseconds) |
| `CONF_MIN` | 0.5 | Minimum confidence threshold for pose detection (0.0-1.0) |

## Manual Acceptance Tests

The following manual tests should be performed to validate the MVP:

### Test 1: Arms-up triggers PREP state
**Steps:**
1. Launch the application
2. Verify app is in REST state
3. Raise both arms above head
4. Hold position for at least 400ms

**Expected Result:**
- App transitions from REST to PREP state
- 2-second countdown begins
- Visual/audio feedback indicates PREP state

### Test 2: PREP transitions to HANG
**Steps:**
1. Trigger PREP state (as in Test 1)
2. Maintain position or grip hangboard
3. Wait for 2-second countdown to complete

**Expected Result:**
- App transitions from PREP to HANG state
- Main workout timer starts counting
- Visual/audio feedback indicates HANG state

### Test 3: Arms-down ends HANG
**Steps:**
1. Enter HANG state (complete Tests 1 and 2)
2. Wait at least 800ms (grace period)
3. Lower both arms
4. Hold lowered position for at least 400ms

**Expected Result:**
- App transitions from HANG to REST state
- Timer stops and displays final hang duration
- Visual/audio feedback indicates hang completion

### Test 4: No false stop during grace period
**Steps:**
1. Enter HANG state (complete Tests 1 and 2)
2. Immediately upon entering HANG, briefly lower arms (within first 800ms)
3. Raise arms back up quickly

**Expected Result:**
- App remains in HANG state
- Timer continues running
- Brief arm movement during grace period is ignored
- No premature transition to REST

### Test 5: Low confidence poses are ignored
**Steps:**
1. Launch the application
2. Make partial or unclear arm gestures (confidence < 0.5)
3. Ensure lighting or positioning makes pose detection difficult

**Expected Result:**
- App remains in current state
- Low confidence detections do not trigger state transitions
- App waits for clear, high-confidence pose detection

## Success Criteria

The MVP is considered complete when:
- All five manual acceptance tests pass consistently
- State transitions occur smoothly and predictably
- No false positives or false negatives in typical usage scenarios
- User can complete a full hang workout cycle without manual intervention
