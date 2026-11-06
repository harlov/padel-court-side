# Court Side — Padel Score

Native SwiftUI iPhone and Apple Watch companion apps. iOS 17+ and watchOS 10+. No external dependencies.

## Run

1. Open `PadelScore.xcodeproj` in Xcode.
2. Select your Apple development team in **Signing & Capabilities** for both targets. If needed, change both bundle identifiers and keep the Watch target’s `WKCompanionAppBundleIdentifier` equal to the iPhone identifier.
3. Select the **PadelScore** scheme and an iPhone or paired iPhone/Watch simulator, then Run. Use the **PadelWatch** scheme to launch the Watch app.
4. Start a match on iPhone, rotate to landscape, and open the Watch app.

If command line tools are selected instead of Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project PadelScore.xcodeproj -scheme PadelScore \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/padel-derived CODE_SIGNING_ALLOWED=NO build
```

## Behavior

- Home: resume an active match, start a match, browse completed matches and set scores, open settings.
- Setup: golden point (default) or advantages, team names and contrasting preset colors. Text colors are paired with each preset for readability.
- Rules: best of three sets; six games with a two-game lead, tie-break at 6–6 to seven with a two-point lead. These match rules are fixed in this first version.
- Scoreboard: landscape on iPhone; two colored score panels on both devices. Double tap adds a point. Hold for two seconds (configurable 0.5–5 seconds) to remove that team’s last point.
- Corrections replay the point history, restoring games, sets and match outcome as necessary. Removing a point from a team with no points is a no-op.
- At a game boundary, the final points blink for five seconds, then the game totals blink for five seconds. Each duration is independently configurable from 1–15 seconds. Optional confirmation waits for **Next game** before accepting more points. Holds still correct scores during transitions.
- Completed matches are saved automatically. Matches, settings and current transitions survive app restarts. Returning home does not stop the active match.
- iPhone remains awake while its match screen is visible.

## Sync

The phone is the authority. WatchConnectivity application context publishes the latest persisted snapshot; immediate messages request snapshots and submit uniquely identified scoring commands. Duplicate command identifiers are ignored. The Watch polls during celebrations so the phone can advance transitions even when its UI is in the background. This follows Apple’s [application-context model](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)).

Watch scoring requires a reachable paired iPhone. Offline scoring is blocked with a visible message; points are not silently queued. If acknowledgement fails, check the phone before retrying. Real-device connectivity, background execution, and gestures still need paired-device validation.

## Source map

- `Sources/PadelCore/Match.swift`: Codable match state, scoring, replay corrections and timed phases. Also compiled directly into each app.
- `Shared/MatchStore.swift`: persistence and phone-authoritative synchronization.
- `Shared/Scoreboard.swift`: shared score panels, gestures and transition display.
- `iPhone/PadelApp.swift`: home, setup, settings, match screen and results.
- `Watch/PadelWatchApp.swift`: companion entry point and empty state.
- `Tests/PadelCoreTests`: rule, tie-break, correction, serialization and transition tests.
- `scripts/generate_project.py`: regenerates the checked-in Xcode project without third-party tooling. Re-running replaces project configuration edits.

## Validation

Both simulator app targets build with code signing disabled. Six Swift scoring tests pass. The iPhone app was installed and launched in Simulator, and its home screen was visually checked. App Store icons, provisioning, distribution setup, and a full paired-device acceptance pass remain before release.

Manual acceptance: score on both devices; verify each reaches the same score; try long holds without triggering double taps; test deuce under both rules; correct a game/set-winning point; test both celebration durations and confirmation; suspend/relaunch each app; disconnect/reconnect the Watch; inspect the smallest supported Watch size.
