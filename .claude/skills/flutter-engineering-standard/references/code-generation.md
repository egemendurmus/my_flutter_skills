# Code generation contract

Source inspiration: VB10/flight_booking `docs/codegen_and_localization.md` and `scripts/generate.sh` approach: one entry point, typed references, no manual edits to generated output.

## CREATE
1. Inspect Dart/Flutter SDK and package compatibility before selecting generators.
2. Use `freezed` and `json_serializable` where immutable models/JSON need generation; typed `go_router_builder` routes where beneficial; `flutter_gen` for asset/font references if compatible; a localization generator or Flutter's `gen_l10n` according to project needs.
3. Create `scripts/generate.sh` (or a cross-platform Dart equivalent) as a single documented entry point. Only invoke commands for dependencies actually declared and available. Include a `--check` or CI verification workflow when supported.
4. Put generated output in predictable paths, mark it generated, and never hand-edit `*.g.dart`, `*.freezed.dart`, generated routes/assets/localization files.
5. Keep locale keys aligned across languages, support placeholders/plurals, and use typed asset references instead of raw widget path strings.
6. Provide an executable generation command, required dependencies, expected outputs and a verification test. Check generator output for drift before claiming success.

## EVOLVE
Inventory current generators and source-of-truth files. Keep existing conventions where working; consolidate duplicate scripts without changing model wire formats or localization keys. Introduce generators incrementally, never silently overwrite user-maintained source.
