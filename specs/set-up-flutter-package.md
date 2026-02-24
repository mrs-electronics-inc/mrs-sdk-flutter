---
number: 1
status: draft
author: Addison Emig
creation_date: 2026-02-24
---

# Set up Flutter package on pub.dev

Define the work required to prepare, validate, and publish this package on `pub.dev` with a repeatable release workflow.

This spec covers package metadata, repository/package structure expectations, publication checks, CI/CD quality gates, Nix-based development environment setup, and release documentation so maintainers can publish new versions consistently.

## Design Decisions

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

### CI/CD Quality Gates

- Chosen: Add CI/CD pipelines to enforce linting and formatting on every change
  - CI must run linter checks using repository recipes
  - CI must run formatter checks and fail when formatting drift is detected
  - Publish workflow depends on green quality gates

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

### Package Metadata and Layout

- [ ] Add checks first for required pub.dev metadata fields in `pubspec.yaml` and supporting files
- [ ] Ensure package metadata is complete and publishable (`name`, `version`, `description`, `homepage`/`repository`, SDK constraints, license/readme/changelog presence)
- [ ] Cleanup pass: remove conflicting or duplicated package metadata without changing behavior

### Publish Readiness

- [ ] Add checks first for publish-readiness expectations (analysis, test, lint, dry-run success)
- [ ] Define and validate pre-publish verification flow using repository recipes
- [ ] Define and validate `dart pub publish --dry-run` workflow from the package root
- [ ] Cleanup pass: simplify readiness workflow guidance without changing behavior

### CI/CD Pipelines

- [ ] Add checks first for CI pipeline expectations (lint and format checks required on pull requests and main branch)
- [ ] Define and implement CI linter workflow using repository recipes
- [ ] Define and implement CI formatter workflow as verification (fail on unformatted changes)
- [ ] Cleanup pass: simplify CI workflows without changing enforcement behavior

### Nix Flake Setup

- [ ] Add checks first for Nix environment expectations (flake evaluation, dev shell entry, required tool availability)
- [ ] Add `flake.nix` with inputs (`nixpkgs`, `devshell`, `android-nixpkgs`) and overlay-based Android SDK configuration
- [ ] Add/align `devshell.nix` integration and verify `devShell` wiring from flake outputs
- [ ] Ensure Android SDK package set includes: `build-tools-35-0-0`, `cmdline-tools-latest`, `platform-tools`, `platforms-android-31`, `platforms-android-33`, `platforms-android-34`, `platforms-android-35`, `platforms-android-36`, `ndk-28-2-13676358`, `cmake-3-22-1`
- [ ] Cleanup pass: remove redundant environment setup paths without changing behavior

### Release Process

- [ ] Add checks first for release versioning/changelog requirements
- [ ] Define version bump and changelog update process for each release
- [ ] Define publish execution and post-publish traceability steps (including git tag/version reference)
- [ ] Cleanup pass: streamline release steps without changing behavior

### Documentation

- [ ] Update docs with a canonical `pub.dev` publishing guide for maintainers
- [ ] Ensure docs clearly separate pre-publish checks, dry-run, and real publish steps
- [ ] Document CI/CD quality gate expectations for lint and formatter pipelines
- [ ] Document Nix flake/dev shell setup and usage for contributors
- [ ] Add troubleshooting guidance for common publish failures (metadata, score, authentication, dry-run errors) and environment setup failures
