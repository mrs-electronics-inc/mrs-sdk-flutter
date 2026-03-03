# Release Process Checklist

Use this checklist before package publish work:

1. Update `pubspec.yaml` version to the intended release version (`X.Y.Z`).
2. Update `CHANGELOG.md` with release notes for `X.Y.Z`.
3. Commit release changes and push to the default branch.
4. Create and push tag `vX.Y.Z` (for example `git tag v0.2.0 && git push origin v0.2.0`) to trigger `.github/workflows/publish-pubdev.yml`.
5. Monitor the workflow run and confirm the automated gate order completes as `quality_gates` -> `tag_version_check` -> `dry_run_publish` -> `publish`.
6. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter/versions`.
7. Record deployment traceability links in release notes or issue tracker: pushed tag (`vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.

Automated by CI/CD in `.github/workflows/publish-pubdev.yml` after tag push:
- `quality_gates` (format, analyze, tests, docs checks)
- `tag_version_check` (tag format and tag-to-`pubspec.yaml` version match)
- `dry_run_publish` (`dart pub publish --dry-run`)
- `publish` (`dart pub publish --force`, protected by `pubdev-release` environment approval)
