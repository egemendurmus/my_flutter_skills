#!/usr/bin/env python3
"""Non-destructive heuristic check of a Flutter project's basic structure."""
import argparse
from pathlib import Path


def inspect(root: Path) -> tuple[list[str], list[str]]:
    errors, warnings = [], []
    if not root.is_dir():
        return [f"Project root does not exist: {root}"], warnings
    if not (root / "pubspec.yaml").is_file():
        errors.append("Missing pubspec.yaml")
    if not (root / "lib" / "main.dart").is_file():
        errors.append("Missing lib/main.dart")
    if not (root / "test").is_dir():
        warnings.append("No test/ directory found")
    if not (root / "analysis_options.yaml").is_file():
        warnings.append("No analysis_options.yaml found")
    if (root.joinpath("lib").is_dir()):
        dart_files = list(root.joinpath("lib").rglob("*.dart"))
        if not dart_files:
            warnings.append("No Dart source files under lib/")
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", type=Path)
    args = parser.parse_args()
    errors, warnings = inspect(args.project_root.resolve())
    for issue in errors:
        print(f"ERROR: {issue}")
    for issue in warnings:
        print(f"WARN: {issue}")
    print("Structure check:", "FAIL" if errors else "PASS")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
