# Release Process Checklist

Use this checklist before package publish work:

1. Update `pubspec.yaml` version to the intended release version (`X.Y.Z`).
2. Update `CHANGELOG.md` with release notes for `X.Y.Z`.
3. Run `just lint`.
4. Run `just test`.
5. Run `dart pub publish --dry-run`.
6. Commit release changes and push to the default branch.
7. Create and push tag `vX.Y.Z` (for example `git tag v0.2.0 && git push origin v0.2.0`) to trigger `.github/workflows/publish-pubdev.yml`.
8. Confirm the workflow job order completes as `quality_gates` -> `tag_version_check` -> `dry_run_publish` -> `publish`.
9. Verify the package version appears on `https://pub.dev/packages/mrs_sdk_flutter/versions`.
10. Record deployment traceability links in release notes or issue tracker: pushed tag (`vX.Y.Z`), successful GitHub Actions run, and published `pub.dev` version page.
