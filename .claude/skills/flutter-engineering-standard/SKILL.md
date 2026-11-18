---
name: flutter-engineering-standard
description: Create new Flutter applications or evolve existing Flutter repositories with an adaptive feature-first Clean Architecture and MVVM standard. Use for Flutter scaffolding, feature implementation, architecture reviews, refactoring, Riverpod state, Dio networking, go_router navigation, Freezed models, repository boundaries, and tests. Accept connected GitHub repositories or local source files; deliver complete file-by-file implementation and honest verification results.
---

# Flutter Engineering Standard

Apply the **adaptive** standard: use the preferred stack for greenfield Flutter apps; preserve working behavior, APIs, platform integrations and operational constraints in existing apps. Never rewrite a functioning project solely to match a folder diagram.

## Inputs and access

1. Determine mode: **CREATE** (new application) or **EVOLVE** (existing repository). For CREATE, collect project name, package ID, platforms, and initial feature scope if missing. For EVOLVE, identify repository/branch or local files and the requested change.
2. Inspect actual code and dependencies before proposing edits. Prefer the connected GitHub integration for linked repositories, otherwise use available local source. Do not invent files or claim repository access when unavailable. Never expose secrets found in source.
3. GitHub access is read-only by default. Obtain explicit authorization before committing, opening PRs, pushing or changing remote files. If tools are unavailable, provide a reproducible patch or complete file contents instead.
4. Identify target Flutter/Dart versions from the project. Do not assume dependency versions are compatible; verify with available tooling or mark unverified.

## Workflow

1. **Inspect**: summarize architecture, dependencies, feature boundaries, state flow, native integrations, tests and security risks. For EVOLVE, identify invariants and baseline behavior to preserve.
2. **Decide**: choose the smallest architecture change that solves the task. Explain nontrivial tradeoffs, affected files and migration risks. Keep legacy state management where replacing it is not required.
3. **Implement**: produce full, compilable file contents with exact relative paths and required imports; never use `...` placeholders for essential code. Keep changes cohesive and bounded. Avoid adding layers without meaningful business logic or substitution needs.
4. **Test**: add unit tests for rules and failure states, widget tests for UI states, integration tests for critical platform/IO paths when feasible. Mock boundaries rather than hardware. Run `dart format`, `flutter analyze`, `flutter test` when an executable Flutter environment is available. Do not claim unexecuted tests passed.
5. **Review**: inspect credentials, input validation, error handling, cancellation/disposal, concurrent requests, offline behavior, logging, permissions and backwards compatibility. See [security-rules.md](references/security-rules.md).
6. **Deliver**: list exact changed files, complete source/patch, dependency commands, tests, execution results vs unverified checks, residual risks and safe rollback.

## Preferred greenfield stack

- Feature-first organization with presentation (MVVM), domain when needed, and data layers. See [architecture.md](references/architecture.md).
- Riverpod 3 for dependency wiring and immutable UI state; Dio behind a network abstraction; go_router for navigation; Freezed/json_serializable for complex immutable models and JSON. See [riverpod-patterns.md](references/riverpod-patterns.md).
- Repository contracts only where substitution, tests, or domain boundaries justify them; use cases only for meaningful orchestration or business rules.
- Favor explicit typed failures and clear loading/error/empty states; avoid mutable global configuration and service locators alongside Riverpod without reason.
- Apply [coding-standards.md](references/coding-standards.md) and [testing-strategy.md](references/testing-strategy.md).

## EVOLVE safeguards

Read [migration-rules.md](references/migration-rules.md). Preserve the existing public behavior and persistence formats; migrate one vertical slice at a time. Record baseline tests or manual verification steps before edits. For industrial apps (VNC/RFB, SSH/SFTP, MSSQL, background tasks), treat connection lifecycle, protocol negotiation, permissions and recovery as first-class invariants. Never send real commands to equipment or mutate production databases without explicit authorization and a safe test plan.

## Output contract

For each implementation, return: (1) mode and objective; (2) assumptions and observed source evidence; (3) impacted file tree; (4) full content of every new/changed file or a precise unified diff when explicitly requested; (5) install/generation/format/analyze/test commands; (6) tests and their actual run status; (7) risk/rollback notes. If output is too large, deliver a logically complete vertical slice rather than incomplete snippets. Follow [output-contract.md](references/output-contract.md).

## Structural validation

When project files are locally available, run `python scripts/validate_structure.py <flutter-project-root>` for a non-destructive heuristic check. This does **not** replace `flutter analyze` or `flutter test`.

## Standardized delivery extensions (v1.1)

For CREATE, establish a reusable design system, deterministic code generation, and an architecture review gate before expanding features. For EVOLVE, adopt each extension only where it improves the existing code without forcing a rewrite. Follow [design-system.md](references/design-system.md), [code-generation.md](references/code-generation.md), and [architecture-reviewer.md](references/architecture-reviewer.md).

- **Design system**: centralize semantic colors, typography, spacing, radius and shared interaction/state widgets; use a separate local `ui_kit` package when multiple features or apps justify it. Prefer `ThemeExtension` and `ColorScheme`, avoid feature-specific raw colors and duplicate buttons. Include widget and accessibility tests.
- **Code generation**: establish a single documented generation entry point for models, typed go_router routes, assets/fonts and localization keys *only for generators actually installed*. Never edit generated output manually; check generated-file consistency in CI. Do not invent APIs or dependency versions.
- **Architecture reviewer**: inspect the changed files and their dependencies against this skill's actual rules, with severity, file:line evidence, corrective action and relevant tests. Distinguish static review from commands executed. Require format, analyze and test gates where tooling exists; no invented passing results.
- **State and DI**: retain Riverpod 3 for CREATE; do not import VB10's Cubit, `get_it`, global singletons or obligatory page mixins. Preserve existing state management in EVOLVE unless a change specifically warrants migration.
