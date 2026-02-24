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
  - Provide Android SDK tooling via overlay configuration
  - Expose a `devShell` entry that imports `devshell.nix`
- Chosen: Use an Android SDK package set aligned with the requested baseline
  - `build-tools-35-0-0`
  - `cmdline-tools-latest`
  - `platform-tools`
  - `platforms-android-31`
  - `platforms-android-33`
  - `platforms-android-34`
  - `platforms-android-35`
  - `platforms-android-36`
  - `ndk-28-2-13676358`
  - `cmake-3-22-1`

### Publication Target

- Chosen: Publish as a standard Dart/Flutter package on `pub.dev`
  - Uses `pub.dev` package discovery, scoring, and versioning ecosystem
  - Keeps distribution aligned with standard Flutter dependency workflows

### Release Source of Truth

- Chosen: `pubspec.yaml` is the authoritative package metadata source
  - Name, version, description, homepage/repository, environment constraints, and dependencies are defined there
  - Release docs must reflect `pubspec.yaml` fields and not duplicate conflicting metadata

### Release Validation Workflow

- Chosen: Validate package readiness before publish with deterministic checks
  - Run package analysis/tests/lints via repo recipes
  - Run package publish readiness check (`dart pub publish --dry-run` from package root)
  - Fix score/compliance issues before attempting real publish

### CI/CD Workflows

- Chosen: Add CI/CD pipelines to enforce linting and formatting on every change
  - CI must run linter checks using repository recipes
  - CI must run formatter checks and fail when formatting drift is detected
  - Publish workflow depends on green quality gates
- Chosen: Add a CI/CD deployment pipeline for package publication
  - Deployment is triggered from a controlled release flow (tag/release/manual dispatch)
  - Deployment requires successful quality gates and publish dry-run checks
  - Deployment publishes to `pub.dev` using CI-managed credentials/secrets
- Chosen: Implement deployment as a dedicated publish workflow with explicit gates
  - Workflow file: `.github/workflows/publish-pubdev.yml`
  - Triggers:
    - `push` tag matching release pattern (for example `v*.*.*`)
  - Job order:
    - `quality_gates` (lint/format/test verification)
    - `dry_run_publish` (`dart pub publish --dry-run`)
    - `publish` (real publish) only after prior jobs succeed
  - `publish` job runs in a protected GitHub Environment (for example `pubdev-release`) requiring approval
- Chosen: Define credential handling contract for CI publish
  - Store token in GitHub Actions secret (for example `PUB_DEV_PUBLISH_TOKEN`)
  - Configure Dart publish auth in CI via `dart pub token add https://pub.dev --env-var PUB_DEV_PUBLISH_TOKEN`
  - Never store pub.dev credentials in repository files

### Publishing Workflow

- Chosen: Document and follow a repeatable release sequence
  - Bump version in `pubspec.yaml`
  - Update changelog for the release
  - Run verification and dry-run publish
  - Publish to `pub.dev`
  - Tag/version reference in git for traceability

### Documentation Ownership

- Chosen: Release instructions are documented in project docs and point to executable commands/recipes
  - Avoid hidden maintainer knowledge
  - Keep onboarding and release process maintainable

## Task List

### Nix Flake Setup

- [ ] Add checks first for Nix environment expectations (flake evaluation, dev shell entry, required tool availability)
- [ ] Add `flake.nix` with inputs (`nixpkgs`, `devshell`, `android-nixpkgs`) and overlay-based Android SDK configuration
- [ ] Add/align `devshell.nix` integration and verify `devShell` wiring from flake outputs
- [ ] Ensure Android SDK package set includes: `build-tools-35-0-0`, `cmdline-tools-latest`, `platform-tools`, `platforms-android-31`, `platforms-android-33`, `platforms-android-34`, `platforms-android-35`, `platforms-android-36`, `ndk-28-2-13676358`, `cmake-3-22-1`
- [ ] Cleanup pass: remove redundant environment setup paths without changing behavior

### Package Metadata and Layout

- [ ] Add checks first for required pub.dev metadata fields in `pubspec.yaml` and supporting files
- [ ] Ensure package metadata is complete and publishable (`name`, `version`, `description`, `homepage`/`repository`, SDK constraints, license/readme/changelog presence)
- [ ] Cleanup pass: remove conflicting or duplicated package metadata without changing behavior

### Publish Readiness

- [ ] Add checks first for publish-readiness expectations (analysis, test, lint, dry-run success)
- [ ] Define and validate pre-publish verification flow using repository recipes
- [ ] Define and validate `dart pub publish --dry-run` workflow from the package root
- [ ] Cleanup pass: simplify readiness workflow guidance without changing behavior

### PR Workflows

- [ ] Add checks first for PR workflow expectations (lint and formatter checks required on pull requests)
- [ ] Define and implement PR linter workflow using repository recipes
- [ ] Define and implement PR formatter workflow as verification (fail on unformatted changes)
- [ ] Ensure PR workflow blocks merge when required quality checks fail
- [ ] Cleanup pass: simplify PR workflows without changing enforcement behavior

### Release Workflows

- [ ] Add checks first for release workflow expectations (tag trigger only, required gates, publish permissions)
- [ ] Add `.github/workflows/publish-pubdev.yml` with tag-based release trigger only (`push` tags matching release pattern)
- [ ] Define and implement release deployment workflow for `pub.dev` publish from release tags
- [ ] Ensure release workflow requires successful quality gates and `dart pub publish --dry-run` before publish
- [ ] Ensure release quality gates include a check that git tag version matches `pubspec.yaml` version
- [ ] Ensure release workflow uses explicit job dependencies: `quality_gates` -> `dry_run_publish` -> `publish`
- [ ] Ensure publish job executes in protected deployment environment with approval gate
- [ ] Ensure release workflow uses secure credential management for `pub.dev` publishing
- [ ] Ensure CI publish auth is configured with `dart pub token add https://pub.dev --env-var PUB_DEV_PUBLISH_TOKEN`
- [ ] Cleanup pass: simplify release workflows without changing enforcement behavior

### Release Process

- [ ] Add checks first for release versioning/changelog requirements
- [ ] Define version bump and changelog update process for each release
- [ ] Define release-to-deploy handoff steps (including git tag/version reference) that trigger CI deployment
- [ ] Define post-publish traceability steps for published versions and deployment records
- [ ] Cleanup pass: streamline release steps without changing behavior

### Documentation

- [ ] Update docs with a canonical `pub.dev` publishing guide for maintainers
- [ ] Ensure docs clearly separate pre-publish checks, dry-run, and real publish steps
- [ ] Document PR workflow quality gate expectations for lint and formatter pipelines
- [ ] Document release workflow trigger/gating rules, protected environment usage, and credential requirements
- [ ] Document Nix flake/dev shell setup and usage for contributors
- [ ] Add troubleshooting guidance for common publish failures (metadata, score, authentication, dry-run errors) and environment setup failures
