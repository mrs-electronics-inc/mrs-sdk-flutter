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
- [ ] Cleanup pass: remove redundant environment setup paths without changing behavior

### Package Metadata and Layout

- [ ] Add checks first for required pub.dev metadata fields in `pubspec.yaml` and supporting files
- [ ] Ensure package metadata is complete and publishable (`name`, `version`, `description`, `homepage`/`repository`, SDK constraints, dependency constraints, `documentation`, `issue_tracker`)
- [ ] Ensure required support files are present and updated (`README.md`, `CHANGELOG.md`, `LICENSE`)
- [ ] Ensure Flutter `example/` app is present and valid for package usage demonstration
- [ ] Cleanup pass: remove conflicting or duplicated package metadata without changing behavior

### Publish Readiness

- [ ] Add checks first for publish-readiness expectations (analysis, test, lint, dry-run success)
- [ ] Define and validate pre-publish verification flow using repository recipes
- [ ] Define and validate `dart pub publish --dry-run` workflow from the package root
- [ ] Cleanup pass: simplify readiness workflow guidance without changing behavior

### PR Workflows

- [ ] Add checks first for PR workflow expectations (quality gates run on pull requests via reusable workflow)
- [ ] Define reusable quality-gates workflow/job (Ubuntu runner) shared by PR and release workflows
- [ ] Implement quality-gate command steps (no `just`): `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `npm --prefix docs run lint`, `npm --prefix docs run format:check`
- [ ] Implement PR workflow that calls reusable quality-gates workflow
- [ ] Ensure PR workflow blocks merge when required quality checks fail
- [ ] Cleanup pass: simplify PR workflows without changing enforcement behavior

### Release Workflows

- [ ] Add checks first for release workflow expectations (tag trigger only, required gates, publish permissions)
- [ ] Add `.github/workflows/publish-pubdev.yml` with tag-based release trigger only (`push` tags matching `vX.Y.Z`)
- [ ] Define and implement release deployment workflow for `pub.dev` publish from release tags
- [ ] Ensure release workflow calls reusable quality-gates workflow before any publish steps
- [ ] Ensure release quality gates include a check that git tag version matches `pubspec.yaml` version
- [ ] Ensure tag/version mismatch fails workflow before `dry_run_publish` and `publish`
- [ ] Ensure release workflow uses explicit job dependencies: `quality_gates` -> `tag_version_check` -> `dry_run_publish` -> `publish`
- [ ] Ensure publish job executes in GitHub Environment `pubdev-release` with one maintainer approval
- [ ] Ensure release workflow uses secure credential management for `pub.dev` publishing
- [ ] Ensure CI publish auth is configured with `dart pub token add https://pub.dev --env-var PUB_DEV_PUBLISH_TOKEN`
- [ ] Add setup prerequisites for maintainers: configure `pubdev-release` environment and `PUB_DEV_PUBLISH_TOKEN` secret
- [ ] Cleanup pass: simplify release workflows without changing enforcement behavior

### Release Process

- [ ] Add checks first for release versioning/changelog requirements
- [ ] Define version bump and changelog update process for each release
- [ ] Define release-to-deploy handoff steps (including git tag/version reference) that trigger CI deployment
- [ ] Define post-publish traceability steps for published versions and deployment records
- [ ] Cleanup pass: streamline release steps without changing behavior

### Workflow Comments

- [ ] Add clear inline comments in PR and release workflow files explaining trigger, gate order, and failure behavior
- [ ] Add clear inline comments for version/tag parity checks and publish safeguards
- [ ] Add clear inline comments describing publish credential setup requirements and secret usage
