# Release Process Checklist

Use this checklist before package publish work:

1. Update `pubspec.yaml` version to the intended release version (`X.Y.Z`).
2. Update `packages/mrs_flutter_lints/pubspec.yaml` to the same version (`X.Y.Z`).
3. Update `CHANGELOG.md` with release notes for `X.Y.Z`.
4. Update the `README.md` dependency example to the latest release version (`mrs_sdk_flutter: ^X.Y.Z`).
5. Commit release changes and push the release branch.
6. Open a pull request for the release branch.
7. Merge the pull request into the default branch.
8. Create and push tag `vX.Y.Z` from the merged default-branch commit (for example `git tag v0.2.0 && git push origin v0.2.0`) to trigger both `.github/workflows/publish-pubdev.yml` and `.github/workflows/publish-mrs-flutter-lints.yml`.
9. Monitor both release workflow runs in GitHub Actions.
10. Approve the `pubdev-release` environment when prompted for each package publish run.
11. Verify both `publish` jobs succeed.
12. Verify the package versions appear on `https://pub.dev/packages/mrs_sdk_flutter/versions` and `https://pub.dev/packages/mrs_flutter_lints/versions`.
13. Record deployment traceability links in release notes or issue tracker: pushed tag (`vX.Y.Z`), successful GitHub Actions runs, and published `pub.dev` version pages.

Automated by CI/CD after tag push:

- `.github/workflows/publish-pubdev.yml` for `mrs_sdk_flutter`: `quality_gates`, `tag_version_check`, `dry_run_publish`, and `publish`
- `.github/workflows/publish-mrs-flutter-lints.yml` for `mrs_flutter_lints`: the same gate sequence, scoped to `packages/mrs_flutter_lints`
