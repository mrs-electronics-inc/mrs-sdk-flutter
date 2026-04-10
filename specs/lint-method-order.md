---
number: 5
status: completed
author: Addison Emig
creation_date: 2026-04-01
---

# Lint Method Order

Add a new lint rule for method order within Flutter widget classes.

## Design Decisions

Desired order, following the Flutter
[State<T extends StatefulWidget>](https://api.flutter.dev/flutter/widgets/State-class.html)
docs:

- fields and constants
- getters and setters
- constructor
- `initState`
- `didChangeDependencies`
- `build`
- `didUpdateWidget`
- `reassemble`
- `deactivate`
- `dispose`
- public methods
- private methods

## Task List

- [x] Define the enforced member order for Flutter widget and `State` classes.
- [x] Implement the lint and tests for the current widget member ordering rule.
- [x] Document the enforced order in the spec and Dart API docs.
