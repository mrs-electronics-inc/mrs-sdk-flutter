# Release Process Checklist

Use this checklist before package publish work:

## Repository Setup

The draft-release and release-tag workflows both use a GitHub App installation token so tag pushes can still trigger downstream publish workflows.

1. Register a GitHub App in the repository owner account or organization.
2. Grant the app `Contents: Read and write` and `Pull requests: Read and write`.
3. Install the app on this repository.
4. Save the app ID as the repository secret `RELEASE_BOT_APP_ID`.
5. Save the app private key as the repository secret `RELEASE_BOT_PRIVATE_KEY`.
6. Keep the app installed on the repository so workflow-generated tag pushes continue to trigger `.github/workflows/publish-sdk.yml` and `.github/workflows/publish-lints.yml`.

## `mrs_sdk_flutter`

1. Run the `Draft Release` workflow and choose `sdk` plus the desired version bump.
2. Review the generated pull request, add or refresh `CHANGELOG.md` notes, and confirm the README install example still matches the version bump.
3. Merge the pull request into `main`.
4. Let the `Release` workflow create and push tag `vX.Y.Z` from the merged commit.
5. Monitor `.github/workflows/publish-sdk.yml` after the tag push.
6. Approve the `pubdev-release` environment when prompted.
7. Verify the `publish` job succeeds.
8. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter/versions`.
9. Record deployment traceability links in release notes or issue tracker: merged release PR, pushed tag (`vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.

Automated by CI/CD in `.github/workflows/release.yml` and `.github/workflows/publish-sdk.yml`:

- `Release` detects the version bump on `main` and pushes `vX.Y.Z`
- `quality_gates` (format, analyze, tests, docs checks)
- `tag_version_check` (tag format and tag-to-`pubspec.yaml` version match)
- `dry_run_publish` (`dart pub publish --dry-run`)
- `publish` (`dart pub publish --force`, protected by `pubdev-release` environment approval)

## `mrs_sdk_flutter_lints`

1. Run the `Draft Release` workflow and choose `lints` plus the desired version bump.
2. Review the generated pull request, add or refresh `lints/CHANGELOG.md` notes, and confirm the README install example still matches the version bump.
3. Merge the pull request into `main`.
4. Let the `Release` workflow detect the `lints/pubspec.yaml` change and push tag `lints-vX.Y.Z` from the merged commit.
5. Monitor `.github/workflows/publish-lints.yml` after the tag push.
6. Approve the `pubdev-release` environment when prompted.
7. Verify the `publish` job succeeds.
8. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter_lints/versions`.
9. Record deployment traceability links in release notes or issue tracker: merged release PR, pushed tag (`lints-vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.

Automated by CI/CD in `.github/workflows/release.yml` and `.github/workflows/publish-lints.yml`:

- `Release` detects the `lints/pubspec.yaml` version bump on `main` and pushes `lints-vX.Y.Z`
- `tag_version_check` (tag format and tag-to-`mrs_sdk_flutter_lints/pubspec.yaml` version match)
- `dry_run_publish` (`dart pub publish --dry-run` from `lints/`)
- `publish` (`dart pub publish --force`, protected by `pubdev-release` environment approval)
