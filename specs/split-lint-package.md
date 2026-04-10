---
number: 6
status: completed
author: Codex
creation_date: 2026-04-10
---

# Split Lint Package

Move the custom analyzer lint rules into a standalone Dart package that does not depend on Flutter.

## Design Decisions

- Keep the Flutter SDK package focused on runtime SDK code only.
- Create a separate `mrs_sdk_flutter_lints` package at the repository root.
- Make the lint package depend on `analysis_server_plugin` and `analyzer`, but not `flutter`.
- Keep the widget member order rule behavior unchanged while relocating its implementation.
- Update repository recipes so dependency fetch, analysis, and tests cover both packages.

## Task List

- [x] Create the standalone lint package with its own package metadata, analyzer plugin entry point, and lint exports.
- [x] Move the widget member order lint implementation and tests into the standalone lint package.
- [x] Remove lint plugin sources and analyzer dependencies from the Flutter SDK package.
- [x] Update repository recipes so dependency fetch, lint, test, and format commands cover both packages.
