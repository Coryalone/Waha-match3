# Staged Implementation Roadmap

## Phase 1: Scaffold

- Create project metadata.
- Add repository hygiene files.
- Add privacy/security requirements.
- Add a minimal Flutter entry point.
- Add Android manifest baseline without internet permission.

## Phase 2: Game Core

- Pure Dart models for board, gem, position, swap, match groups, and move results.
- Board generation with no initial matches.
- Ensure at least one valid move exists.
- Swap validation.
- Match detection.
- Clear, gravity, refill, cascade.
- Reshuffle when no valid moves exist.

## Phase 3: Unit Tests

- Initial board has no matches.
- Initial board has an available move.
- Invalid swap is rejected and does not score.
- Valid swap clears matches.
- Intersecting matches score unique gems once.
- Cascades continue until stable.
- Reshuffle creates a playable stable board.

## Phase 4: Flutter UI and Swipe

- Main menu.
- Game screen.
- 8x8 responsive portrait board.
- Six gem types with color and symbol.
- Swipe input locked during board operations.

## Phase 5: Levels and Scoring

- Five levels.
- 100 points per level.
- Level complete and demo complete screens.

## Phase 6: Local Persistence

- Save current level.
- Save score.
- Save board.
- Save sound setting.
- Restore only stable logical state.

## Phase 7: Animation and Polish

- Swap animation.
- Invalid swap return animation.
- Clear animation.
- Fall/refill animation.
- Initial board fill animation.
- Minimal heraldic visual style.

## Phase 8: Optional Audio

- Add only if the dependency review is clean.
- One sound toggle.
- No telemetry-capable audio SDK.

## Phase 9: Android APK

- Generate local test APK.
- Keep package id and signing setup stable between test builds.

## Phase 10: Privacy/Security Audit

- Inspect manifest.
- Inspect dependencies.
- Confirm no internet permission.
- Confirm backup disabled.
- Confirm no unnecessary permissions.
