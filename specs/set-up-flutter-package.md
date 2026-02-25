---
number: 1
status: draft
author: Addison Emig
creation_date: 2026-02-24
---

# Set Up Flutter Package on pub.dev

Define the work required to prepare, validate, and publish this package on `pub.dev` with a repeatable release workflow.

This spec covers package metadata, repository/package structure expectations, publication checks, CI/CD quality gates, Nix-based development environment setup, and release documentation so maintainers can publish new versions consistently.

## Design Decisions

### Nix Development Environment

- Chosen: Add a Nix flake-based dev environment for reproducible tooling setup
  - Include flake inputs for `nixpkgs`, `devshell`, and `android-nixpkgs`
  - Expose a `devShell` entry that imports `devshell.nix`
- Chosen: Nix setup is optional and targeted
  - Nix docs are for Nix/NixOS users and maintainers, not required for all contributors
  - Non-Nix developers continue to use standard project setup workflows
  - No Nix verification workflow is required in CI/CD for this scope
- Chosen: Nix inputs are pinned for reproducibility
  - `flake.lock` is committed and treated as the authoritative pin set
  - `flake.nix` retains readable input definitions while lockfile controls exact revisions

### Publication Target

- Chosen: Publish as a standard Dart/Flutter package on `pub.dev`
  - Uses `pub.dev` package discovery, scoring, and versioning ecosystem
  - Keeps distribution aligned with standard Flutter dependency workflows

### Release Source of Truth

- Chosen: `pubspec.yaml` is the authoritative package metadata source
  - Name, version, description, homepage/repository, environment constraints, and dependencies are defined there
  - Release docs must reflect `pubspec.yaml` fields and not duplicate conflicting metadata
- Chosen: Pub.dev readiness requires complete metadata and package-support files
  - Required files include `README.md`, `CHANGELOG.md`, and `LICENSE`
  - Flutter package readiness includes an `example/` app for usage validation
  - Recommended `pubspec.yaml` metadata includes `documentation` and `issue_tracker`

### Release Validation Workflow

- Chosen: Validate package readiness before publish with deterministic checks
  - Run package analysis/tests/lints via repo recipes
  - Run package publish readiness check (`dart pub publish --dry-run` from package root)
  - Fix score/compliance issues before attempting real publish

### CI/CD Workflows

- Chosen: Add CI/CD pipelines to enforce linting and formatting on every change
  - CI runs direct commands (not `just`) to avoid extra tool bootstrap in workflows
  - Publish workflow depends on green quality gates
- Chosen: Define quality-gate checks once and reuse across PR and release workflows
  - Reusable workflow/job runs on Ubuntu
  - Quality gates include:
  - `dart format --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
  - `npm --prefix docs run lint`
  - `npm --prefix docs run format:check`
- Chosen: Add a CI/CD deployment pipeline for package publication
  - Deployment is triggered by release tags only
  - Deployment requires successful quality gates and publish dry-run checks
  - Deployment publishes to `pub.dev` using CI-managed credentials/secrets
- Chosen: Implement deployment as a dedicated publish workflow with explicit gates
  - Workflow file: `.github/workflows/publish-pubdev.yml`
  - Triggers:
    - `push` tags matching `vX.Y.Z` only (no prerelease suffixes)
  - Job order:
    - `quality_gates` (lint/format/test verification)
    - `tag_version_check` (verify git tag version equals `pubspec.yaml` version)
    - `dry_run_publish` (`dart pub publish --dry-run`)
    - `publish` (real publish) only after prior jobs succeed
  - `tag_version_check` failure stops the workflow before `dry_run_publish` and `publish`
  - `publish` job runs in GitHub Environment `pubdev-release` with exactly one maintainer approval
- Chosen: Define credential handling contract for CI publish
  - Store token in GitHub Actions secret (for example `PUB_DEV_PUBLISH_TOKEN`)
  - Configure Dart publish auth in CI via `dart pub token add https://pub.dev --env-var PUB_DEV_PUBLISH_TOKEN`
  - Never store pub.dev credentials in repository files
- Chosen: GitHub release prerequisites are explicit
  - Maintainers must configure `pubdev-release` environment with required reviewer approval
  - Maintainers must set `PUB_DEV_PUBLISH_TOKEN` in repository/environment secrets before first publish
- References:
  - GitHub Actions environments: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment
  - Managing environments for deployment: https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-environments-for-deployment
  - Encrypted secrets in GitHub Actions: https://docs.github.com/actions/security-guides/encrypted-secrets

### Publishing Workflow

- Chosen: Document and follow a repeatable release sequence
  - Bump version in `pubspec.yaml`
  - Update changelog for the release
  - Run verification and dry-run publish
  - Publish to `pub.dev`
  - Tag/version reference in git for traceability

### Documentation Ownership

- Chosen: CI/CD workflow files are the canonical maintainer source of truth
  - Workflow files and related release config files must be heavily commented
  - Avoid duplicate process documentation that can drift from executable automation

## Task List

### Nix Flake Setup

- [ ] Add `flake.nix` with inputs (`nixpkgs`, `devshell`, `android-nixpkgs`) and overlay-based Android SDK configuration
- [ ] Add/align `devshell.nix` and ensure flake `devShell` points to it
- [ ] Ensure `flake.lock` is committed and used as the authoritative input pin set
- [ ] Remove redundant or conflicting Nix environment definitions (single canonical `flake.nix` + `devshell.nix` path only)
- [ ] Verify Nix docs scope remains explicit (`optional for Nix users/maintainers`) and does not block non-Nix contributors

### Package Metadata and Layout

- [ ] Update `pubspec.yaml` so publish metadata is complete: `name`, `version`, `description`, `homepage`/`repository`, SDK constraints, dependency constraints, `documentation`, and `issue_tracker`
- [ ] Ensure package-support files exist and are release-ready at package root: `README.md`, `CHANGELOG.md`, and `LICENSE`
- [ ] Remove duplicate package-metadata values from non-`pubspec.yaml` files so `pubspec.yaml` is the only metadata source
- [ ] Confirm `README.md` and `CHANGELOG.md` do not contain metadata values that conflict with `pubspec.yaml`

### Publish Readiness

- [ ] Re-enable `flutter pub get` in `just deps`
- [ ] Re-enable `flutter analyze` in `just lint`
- [ ] Re-enable `dart format .` in `just format`
- [ ] Define and validate the pre-publish readiness flow using repository recipes: `just lint` -> `just test` -> `dart pub publish --dry-run` (from package root), all exit `0`
- [ ] Keep one ordered publish-readiness checklist (`lint` -> `test` -> `dry-run`) with no duplicate steps
- [ ] Ensure each readiness command appears once and matches repository tooling expectations

### PR Workflows

- [ ] Add a reusable quality-gates workflow/job (Ubuntu runner) shared by PR and release workflows, with inline comments explaining commands and failure behavior
- [ ] Implement quality-gate command steps (no `just`): `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `npm --prefix docs run lint`, `npm --prefix docs run format:check` with inline comments for each gate purpose
- [ ] Implement PR workflow that calls reusable quality-gates workflow, with inline comments for trigger and required-check intent
- [ ] Configure PR checks so any failing required quality gate results in a failed PR workflow status
- [ ] Keep quality-gate definitions in one reusable workflow and remove duplicated gate definitions from PR/release workflows
- [ ] Ensure PR workflow comments state gate intent and failure behavior without duplicating external docs

### Release Workflows

- [ ] Add and implement `.github/workflows/publish-pubdev.yml` for tag-triggered (`push` tags `vX.Y.Z`) `pub.dev` deployment, with inline comments documenting trigger constraints
- [ ] Configure release workflow to run the reusable quality-gates workflow before any publish steps, with inline comments on gate ordering
- [ ] Add a `tag_version_check` gate that compares git tag version to `pubspec.yaml` version, with inline comments on mismatch failure behavior
- [ ] Configure dependencies so tag/version mismatch fails before `dry_run_publish` and `publish`
- [ ] Set explicit job dependencies: `quality_gates` -> `tag_version_check` -> `dry_run_publish` -> `publish`
- [ ] Configure `publish` job to run in GitHub Environment `pubdev-release` with one maintainer approval
- [ ] Configure secure `pub.dev` publish auth in release workflow using `PUB_DEV_PUBLISH_TOKEN` and `dart pub token add https://pub.dev --env-var PUB_DEV_PUBLISH_TOKEN`, with inline comments on secret handling
- [ ] Document maintainer setup prerequisites in workflow comments: configure `pubdev-release` environment and `PUB_DEV_PUBLISH_TOKEN` secret
- [ ] Keep one ordered publish path in release workflow: `quality_gates` -> `tag_version_check` -> `dry_run_publish` -> `publish`
- [ ] Ensure release workflow comments cover environment protection, secret usage, and failure conditions at each gate

### Release Process

- [ ] Document version-bump and changelog-update steps for each release
- [ ] Document release-to-deploy handoff steps (including git tag/version reference) that trigger CI deployment
- [ ] Document post-publish traceability steps for published versions and deployment records
- [ ] Ensure no release instructions are duplicated across spec/docs by keeping executable steps only in workflow files and leaving docs to link/reference those files
- [ ] Order release-process steps so they map directly to CI jobs and tag-trigger behavior
