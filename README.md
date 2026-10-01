# Wayk Up

A SwiftUI alarm app for iPhone and iPad running iOS/iPadOS 26 or later. The first version implements math challenges; photo verification is deferred.

## Run

1. Open `WaykUp.xcodeproj` in Xcode 26 or later.
2. Choose the WaykUp scheme and an iPhone or iPad running version 26 or later.
3. For a physical device, select your development team under Signing & Capabilities and change the bundle identifier if needed.
4. Run, add an alarm, and grant alarm permission. Use **Try the math challenge** for an immediate demonstration.

## Behavior

- Completed or externally canceled alarms are removed from storage and the list; snoozed alarms remain active.
- Create and delete named, one-time alarms. The selected time schedules its next occurrence.
- AlarmKit handles background system alarms using the bundled wake.wav. When a math challenge starts, the app stops system playback and loops wake.wav with AVAudioPlayer. Active playback can continue while the screen is locked.
- Tap **Solve math** on the system alarm or open the app while the alarm is ringing.
- Solve exactly two questions using addition or multiplication with operands from 1–12. Incorrect answers do not advance progress.
- After two correct answers, unlock **Stop alarm** and **Snooze for 5 minutes**.
- Snoozing replaces the alarm with a new occurrence; each occurrence starts a fresh two-question session. There is no snooze-count limit.
- Practice mode plays sound immediately and lets users test the challenge without scheduling a system alarm. Finishing practice does not schedule a snooze.

## Platform limitation

Apple's system alarm UI includes a Stop control. Wayk Up cannot enforce its math challenge on that system action, prevent force-quitting, or guarantee that a user cannot bypass the challenge. Challenge gating applies to the app's own controls. Foreground challenge audio loops through AVAudioPlayer; AlarmKit handles sound outside the app. Real-device validation is required for alarm authorization, lock-screen behavior, sound under Focus/silent mode, intent handoff, and snooze scheduling before relying on the app for wake-ups.

## Architecture

- **Domain:** platform-independent alarm model, question generator, and challenge session. The session centralizes the two-question completion rule.
- **Services:** small protocols for scheduling, persistence, and audio; concrete AlarmKit, atomic JSON-file, and AVAudioPlayer adapters.
- **Features:** observable application coordinator and SwiftUI screens. Dependencies are injected at the app composition root; UI does not schedule or stop system alarms directly.
- Future photo verification can be added as a separate challenge step before the math session, keeping camera/verification services out of alarm scheduling and persistence.

## Validation

Run `swift test` for the platform-independent challenge tests. They cover incorrect answers, exactly two successful answers, completed-session behavior, fresh session reset, and generated question ranges.

Unsigned Simulator build:

```sh
xcodebuild -project WaykUp.xcodeproj -scheme WaykUp -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Custom sounds require real-device testing. Apple acknowledged an AlarmKit custom-sound issue in iOS 26.0, with a fix planned for 26.1: https://developer.apple.com/forums/thread/802620 . No app can guarantee suppression of OS sound fallback while terminated. After changing the bundled sound, delete and recreate existing alarms to apply the new configuration.

The challenge audio player explicitly uses full volume (1.0). This does not override the device media volume. iOS keeps system output volume under user control, and AlarmKit has no per-alarm volume setting. Raise media volume for the in-app sound and the alarm/alert volume under Settings → Sounds & Haptics for the system alarm.

## Repeated snooze and pending challenges

Each snooze schedules a fresh occurrence ID and resets both questions. While the app is foreground, a one-second deadline check backs up AlarmKit event delivery. The challenge is part of the root UI instead of a modal, so it can appear during repeated snooze cycles without leaving and reopening the app. System updates are ignored during schedule transactions to avoid prematurely removing an alarm.

Due alarms remain pending until solved in Wayk Up, including when the system UI or a hardware button silences them. System Stop is configured to open the challenge through an App Intent. iOS still stops system sound and retains its Stop gesture; the app cannot remove that gesture, override hardware volume controls, force a locked phone to open an app, or prevent the user from muting/force-quitting. If the app is closed, a silenced alarm cannot be guaranteed to remain audible. Opening Wayk Up resumes the pending challenge. Only future canceled alarms and alarms completed inside Wayk Up are removed from storage.

Audio interruption recovery resumes playback while a challenge is outstanding; it does not override device volume. Validate multiple snooze cycles, foreground firing, interrupted sound, and lock-screen intent behavior on a physical iPhone before relying on these behaviors.
# Wayk-Up
