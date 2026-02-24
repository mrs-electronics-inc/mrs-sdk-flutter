# Agent Guidelines

This repository contains the MRS SDK for Flutter and docs in `docs/`. Docs are deployed at `https://flutter.mrs-electronics.dev`.

## Developer Commands

ALWAYS use `just` recipes from the repository root for development tasks.
Do not run underlying raw commands directly when a recipe exists.

- `just` list available recipes
- `just deps` install Flutter and docs dependencies
- `just setup` run setup and install git hooks
- `just dev` run the Flutter app
- `just lint` run Flutter analysis and docs build checks
- `just test` run Flutter tests
- `just format` format Flutter and docs code
- `just run-docs` run docs locally
