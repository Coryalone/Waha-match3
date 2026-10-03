# Waha Match-3

Offline-first Flutter/Dart Match-3 MVP for local Android testing.

## Project goals

- 8x8 Match-3 board with 6 distinct gem types.
- Pure Dart game core separated from Flutter UI.
- Unit-tested game logic before UI polish.
- 5 demo levels, each completed at 100 points.
- Local-only save state.
- Android APK for local testing.
- Privacy/security by design.

## Privacy and security baseline

This project is intentionally built as a local offline test app.

- No accounts.
- No backend in MVP.
- No analytics.
- No ads.
- No telemetry.
- No crash-reporting SDK.
- No tracking identifiers.
- No `INTERNET` permission for the local test APK.
- No camera, microphone, contacts, location, media, or shared storage permissions.
- Save data must stay in private app-specific storage.
- Android backup must be disabled for the local test APK.

## Development phases

1. Scaffold project structure.
2. Implement pure Dart game core.
3. Add unit tests for game logic.
4. Build Flutter UI and swipe input.
5. Add levels and scoring flow.
6. Add local persistence.
7. Add animations and visual polish.
8. Optional audio, only if it does not add risky dependencies.
9. Build local Android APK.
10. Run privacy/security audit before installing on a main device.

## Current status

Phase 1 is being initialized. Flutter SDK verification and generated platform files should be checked locally before the first APK build.
