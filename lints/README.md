# MRS SDK Flutter Lints

`mrs_sdk_flutter_lints` provides custom analyzer lint rules for Flutter projects that use the MRS SDK.

## Install

Add the plugin to the top-level `plugins` section of your root `analysis_options.yaml`:

```yaml
plugins:
  mrs_sdk_flutter_lints: ^0.6.0
```

Enable the lint rule you want under `diagnostics`:

```yaml
plugins:
  mrs_sdk_flutter_lints:
    diagnostics:
      widget_member_order: true
```

Restart the Dart analysis server after changing plugin configuration.
