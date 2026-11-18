# Coding standards

- Follow `flutter_lints` or the repository's existing analyzer settings; use consistent names and package imports.
- Prefer immutable state and explicit typed inputs/outputs; avoid dynamic, unchecked casts and force unwraps without invariants.
- Keep widgets focused on rendering and interaction; move IO, parsing and business rules to providers/services.
- Await operations that affect state; prevent stale async responses from overwriting newer requests. Cancel or dispose subscriptions, sockets, timers and controllers.
- Use explicit error, loading, success and empty states. Surface user-friendly messages while retaining sanitized diagnostic context.
- Never hardcode credentials, endpoints with secret tokens or customer data. Avoid raw `print` in production paths; redact logs.
- Make native and platform-specific behavior conditional and testable. Maintain locale strings, accessibility and responsive layout.
- Before proposing packages, check current `pubspec.yaml`, lockfile and SDK constraints.
