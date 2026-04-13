# Release Process Checklist

Use this checklist before package publish work:

## Repository Setup

The `Draft Release` workflow uses a GitHub App installation token to open release pull requests.

1. Register a GitHub App in the repository owner account or organization.
2. Grant the app `Contents: Read and write` and `Pull requests: Read and write`.
3. Install the app on this repository.
4. Save the app ID as the repository secret `RELEASE_BOT_APP_ID`.
5. Save the app private key as the repository secret `RELEASE_BOT_PRIVATE_KEY`.

## `mrs_sdk_flutter`

1. Run the `Draft Release` workflow and choose `sdk` plus the desired version bump.
2. Review the generated pull request, add or refresh `CHANGELOG.md` notes, and confirm the README install example and getting-started docs version references still match the version bump.
3. Merge the pull request into `main`.
4. Let [`.github/workflows/release-sdk.yml`](.github/workflows/release-sdk.yml) create and push tag `vX.Y.Z` from the merged commit.
5. Let the same workflow run `flutter pub publish --dry-run` and then publish to `pub.dev`.
6. Approve the `pubdev-release` environment when prompted.
7. Verify the `publish` job succeeds.
8. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter/versions`.
9. Record deployment traceability links in release notes or issue tracker: merged release PR, pushed tag (`vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.

Automated by CI/CD in [`.github/workflows/release-sdk.yml`](.github/workflows/release-sdk.yml):

- `quality_gates` (format, analyze, tests, docs checks)
- `tag_version_check` (version-file, README, docs, and changelog verification)
- `dry_run_publish` (`flutter pub publish --dry-run`)
- `create_release_tag` (annotated `vX.Y.Z` tag push)
- `publish` (`pub.dev` publishing, protected by `pubdev-release` environment approval)

## `mrs_sdk_flutter_lints`

1. Run the `Draft Release` workflow and choose `lints` plus the desired version bump.
2. Review the generated pull request, add or refresh `lints/CHANGELOG.md` notes, and confirm the README install example still matches the version bump.
3. Merge the pull request into `main`.
4. Let [`.github/workflows/release-lints.yml`](.github/workflows/release-lints.yml) create and push tag `lints-vX.Y.Z` from the merged commit.
5. Let the same workflow run `dart pub publish --dry-run` and then publish to `pub.dev`.
6. Approve the `pubdev-release` environment when prompted.
7. Verify the `publish` job succeeds.
8. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter_lints/versions`.
9. Record deployment traceability links in release notes or issue tracker: merged release PR, pushed tag (`lints-vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.

Automated by CI/CD in [`.github/workflows/release-lints.yml`](.github/workflows/release-lints.yml):

- `tag_version_check` (version-file, README, and changelog verification)
- `dry_run_publish` (`dart pub publish --dry-run` from `lints/`)
- `create_release_tag` (annotated `lints-vX.Y.Z` tag push)
- `publish` (`pub.dev` publishing, protected by `pubdev-release` environment approval)
