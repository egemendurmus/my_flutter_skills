# Design system contract

Source inspiration: VB10/flight_booking `module/ui_kit/lib/ui_kit.dart` (component package and tokens). Apply patterns, not its project-specific names or implementation.

## CREATE
1. Define semantic colors via Material `ColorScheme`, extended brand/status tokens via `ThemeExtension`, and named spacing/radius/typography tokens.
2. Provide consistent primitives: button, text field, app bar, card, loading, empty, error, confirmation/dialog, snackbar. Build only components needed by initial scope; avoid an oversized kit.
3. Separate app localization and business logic from reusable widgets; pass resolved labels and callbacks to kit components.
4. For multiple apps or independently reusable features, use `packages/ui_kit/` with a public barrel export; for small apps, start with `lib/core/design_system/` and extract when justified.
5. Generate concrete file-by-file code and widget tests for disabled/loading/error states, tap targets, text scaling and dark/light theme when supported.

## EVOLVE
Audit current tokens/components and preserve their public APIs. Replace duplicate styling incrementally, one feature at a time. Do not add a new package solely for visual consistency if a functioning design system already exists.

## Review checks
No arbitrary per-screen color/spacing literals where semantic tokens exist; no business logic in shared widgets; no inaccessible touch targets; no user-facing strings embedded in reusable kit components unless documented.
