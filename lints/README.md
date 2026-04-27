# MRS SDK Flutter Lints

`mrs_sdk_flutter_lints` provides custom analyzer lint rules for Flutter projects that use the MRS SDK.

## Install

Add the plugin to the `dev_dependencies` of the package you want analyzed:

```yaml
dev_dependencies:
  mrs_sdk_flutter_lints: ^0.6.1
```

If you are using a pub workspace with multiple apps, add it to each app package that should report the lint.

Then enable the plugin in the root `analysis_options.yaml` for that package or workspace:

```yaml
plugins:
  mrs_sdk_flutter_lints:
    version: ^0.6.1
    diagnostics:
      widget_member_order: true
```
