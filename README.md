# My Flutter Skills

Reusable Flutter engineering standards for **Claude Code** and **ChatGPT**.

## Available skill

- **Flutter Engineering Standard v1.1**: Create new Flutter applications, evolve existing applications adaptively, implement features, build a design system, generate code and review architecture. Preferred new-project stack: feature-first MVVM, Riverpod 3, Dio, go_router and optional Freezed/json_serializable.

Source: [`.claude/skills/flutter-engineering-standard/SKILL.md`](.claude/skills/flutter-engineering-standard/SKILL.md).

## Claude Code — project installation

Copy the complete `.claude/skills/flutter-engineering-standard/` directory into the **target Flutter repository** at the same relative path. Claude Code can then discover the project's skill. The included `agents/openai.yaml` is ChatGPT metadata; Claude Code doesn't require it.

The optional reviewer is in `.claude/agents/flutter-architecture-reviewer.md`. Copy it to the target repository if you want a dedicated read-only reviewer.

Skills in this centralized library **do not automatically become active in unrelated repositories**. Install or reference them for each target project.

## ChatGPT

Use the `flutter-engineering-standard/` folder (from inside `.claude/skills/`) when building a single-skill ZIP for your ChatGPT Skills library. The skill entrypoint is `SKILL.md` and includes `agents/openai.yaml`.

## Standards

- **CREATE:** feature-first structure, Riverpod 3, typed navigation, a proportional UI kit, reproducible code generation and tests.
- **EVOLVE:** inspect first, preserve behavior, migrate incrementally, never force a state-management rewrite.
- **REVIEW:** report evidence with file/line, severity and PASS/FAIL/NOT RUN status; never invent a passing test result.
- **REMOTE CHANGES:** read-only by default; request explicit authorization before write operations.

## Verification

Run the non-destructive structural helper from the target Flutter repository:

```bash
python .claude/skills/flutter-engineering-standard/scripts/validate_structure.py .
```

This heuristic check does not replace `flutter analyze` and `flutter test`.

### Acknowledgment

The optional design-system, code-generation and reviewer workflows were informed by the public [VB10/flight_booking](https://github.com/VB10/flight_booking) educational refactoring project; this repository contains an independent Riverpod-oriented adaptation, not a copy of VB10's application.
