# Flutter App Architecture - Implementation Notes

## Overview
This document describes the implemented Flutter app architecture skeleton for the Hangboard Auto Timer.

## Architecture Components

### 1. Pose Detection Service (`lib/pose/pose_service.dart`)
- **Abstract Interface**: `PoseService` defines the contract for pose detection
- **Platform Channel Wrapper**: `PlatformChannelPoseService` provides integration with native ML models (stub implementation)
- **Fake Service**: `FakePoseService` generates fake pose events for testing without ML
- **Key Features**:
  - Detects arm positions (up/down/unknown)
  - Provides confidence scores
  - Stream-based architecture for real-time updates

### 2. Hang State Machine (`lib/logic/hang_controller.dart`)
- Implements the training state machine: **REST → PREP → HANG → REST**
- **States**:
  - `REST`: Waiting for user to begin (arms down)
  - `PREP`: Countdown before hang begins (arms up)
  - `HANG`: Active workout timer (user is hanging)
- **Configurable Parameters**:
  - `upHoldMs`: 400ms - Duration to hold arms up before PREP
  - `downHoldMs`: 400ms - Duration to hold arms down before ending HANG
  - `prepMs`: 2000ms - Preparation countdown duration
  - `stopIgnoreMs`: 800ms - Grace period to prevent false stops
  - `confMin`: 0.5 - Minimum confidence threshold
- **Stream-based State Updates**: Emits `HangStateInfo` with current state and timer values

### 3. Training UI (`lib/ui/training_screen.dart`)
- **Main Screen**: Displays current training state and timers
- **Visual Elements**:
  - State indicator with color coding (grey/orange/green)
  - Large timer display showing:
    - "Ready" in REST state
    - Countdown in PREP state
    - Elapsed time in HANG state
  - Session statistics (number of hangs, total time)
  - Contextual instructions for each state
- **Real-time Updates**: Listens to state machine and updates UI accordingly

### 4. Session Storage (`lib/storage/session_store.dart`)
- **Abstract Interface**: `SessionStore` defines storage operations
- **Data Models**:
  - `HangRecord`: Individual hang with start time and duration
  - `TrainingSession`: Complete session with multiple hangs
- **In-Memory Implementation**: `InMemorySessionStore` for testing
- **Features**:
  - Save/load training sessions
  - Track hang count and total time
  - JSON serialization for persistence (ready for database integration)

## State Machine Flow

```
REST (arms down, ready)
  ↓ (arms up for 400ms)
PREP (2-second countdown)
  ↓ (countdown complete)
HANG (workout timer active)
  ↓ (arms down for 400ms, after 800ms grace period)
REST (session saved)
```

## Current Implementation Status

### ✅ Completed
- [x] All architecture files created
- [x] Abstract interfaces defined
- [x] State machine implemented with proper transitions
- [x] Placeholder UI with state visualization
- [x] Session tracking and storage interface
- [x] Fake pose service for testing
- [x] App compiles successfully with zero errors

### 🔄 Future Work (Not in Scope for This Issue)
- [ ] Integrate actual ML model for pose detection
- [ ] Implement platform channels for iOS/Android
- [ ] Add persistent storage (SQLite/SharedPreferences)
- [ ] Add sound/haptic feedback
- [ ] Add session history view
- [ ] Add configuration UI for timing parameters
- [ ] Add manual testing UI to trigger state transitions

## Testing the App

The app uses `FakePoseService` which automatically generates fake pose events:
- Alternates between "arms down" and "arms up" every 2 seconds
- This allows the state machine to cycle through states automatically
- Perfect for testing the UI and state machine logic without ML

## Running the App

```bash
cd hangboard_auto_timer
flutter pub get
flutter run
```

The app will:
1. Start in REST state
2. Automatically transition through states based on fake events
3. Display real-time state and timer updates
4. Track session statistics

## Code Quality

- ✅ Zero linting errors
- ✅ Zero compilation errors
- ✅ Follows Flutter best practices
- ✅ Well-documented with clear interfaces
- ✅ Stream-based reactive architecture
- ✅ Separation of concerns (pose/logic/ui/storage)
