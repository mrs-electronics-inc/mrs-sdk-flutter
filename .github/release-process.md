# Release Process Checklist

Use this checklist before package publish work:

1. Update `pubspec.yaml` version to the intended release version (`X.Y.Z`).
2. Update `CHANGELOG.md` with release notes for `X.Y.Z`.
3. Update the `README.md` dependency example to the latest release version (`mrs_sdk_flutter: ^X.Y.Z`).
4. Commit release changes and push the release branch.
5. Open a pull request for the release branch.
6. Merge the pull request into the default branch.
7. Create and push tag `vX.Y.Z` from the merged default-branch commit (for example `git tag v0.2.0 && git push origin v0.2.0`) to trigger `.github/workflows/publish-pubdev.yml`.
8. Monitor the release workflow run in GitHub Actions.
9. Approve the `pubdev-release` environment when prompted.
10. Verify the `publish` job succeeds.
11. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter/versions`.
12. Record deployment traceability links in release notes or issue tracker: pushed tag (`vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.

Automated by CI/CD in `.github/workflows/publish-pubdev.yml` after tag push:

- `quality_gates` (format, analyze, tests, docs checks)
- `tag_version_check` (tag format and tag-to-`pubspec.yaml` version match)
- `dry_run_publish` (`dart pub publish --dry-run`)
- `publish` (`dart pub publish --force`, protected by `pubdev-release` environment approval)
