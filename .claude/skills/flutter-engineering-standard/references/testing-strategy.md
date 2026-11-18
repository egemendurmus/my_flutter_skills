# Test strategy

## Unit
Test parsers, validators, repository mappings, use cases and state transitions. Include malformed input, timeouts, cancellations and retries. Mock IO at boundaries.

## Widget
Verify loading, empty, error, success, retry, navigation and localization. Avoid live networks in widget tests.

## Integration
Cover critical native/plugin paths with emulators, fixtures or a staging environment. For VNC/SSH/industrial controllers, use simulated protocol peers; never run destructive tests on production equipment.

## Verification report
Explicitly label `PASS`, `FAIL`, `NOT RUN`, and `BLOCKED`; include commands and actual output when run. Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test` if SDK and dependencies are available. Generated-code steps may require `dart run build_runner build --delete-conflicting-outputs`.
