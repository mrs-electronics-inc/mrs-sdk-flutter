---
number: 4
status: in-progress
author: Addison Emig
creation_date: 2026-03-04
approved_by: Addison Emig
approval_date: 2026-03-04
---

# Improve SpokeZone Integration

Improve the robustness and completeness of Spoke.Zone integration in the Flutter SDK for long-running device workflows and OTA update usage patterns.

This spec focuses on:

- OTA file list filtering support
- OTA model compatibility improvements for typed date handling
- Token lifecycle hardening for proactive refresh and unauthorized recovery
- Live data connection resilience for background runtime stability

## Design Decisions

### OTA Filtering Support

`OtaFilesListOptions` should support OTA filtering fields commonly needed by consumers:

- `module`
- `isActive`

`OtaFilesClient.list(...)` should include these query parameters only when provided, preserving current behavior otherwise.

### OTA Model Typed Date Compatibility

Use typed OTA date fields:

- Set `createdDate` to `DateTime?` parsed from API payload when present.
- Add `DateTime? releaseDate` parsed from API payload when present.

Invalid or missing date strings must map to `null` typed fields and not throw.

### Token Lifecycle Strategy

The SDK should support both proactive and reactive token handling:

- Proactive refresh: refresh device token when JWT `exp` is within 12 hours.
- Reactive unauthorized recovery: on HTTP `401`, invalidate cached token and retry once.

Unauthorized retry behavior is strictly bounded to one retry per request to prevent retry loops.

### Auth Invalidation Capability

Add an optional auth-provider capability for cache invalidation:

- `InvalidatableAccessTokenProvider` with `invalidateToken()`.
- `DeviceAuth` implements this capability.

Shared authorized-request helpers use invalidation behavior only when available; non-invalidatable providers keep existing behavior.

### Token Update Hook

Allow consumers to persist refreshed tokens without replacing SDK auth internals:

- Add optional callback to `DeviceAuthCallbacks`:
  - `FutureOr<void> Function(String token)? onTokenUpdated`

Invoke this callback whenever the active token is updated after login/refresh.

### Live Data Resilience

`LiveData` should be resilient in long-running sessions:

- Add bounded MQTT connect timeout (`connectTimeout`, default 20 seconds).
- Automatically reconnect after unexpected transport disconnect when connection intent remains active.
- Use existing shared backoff strategy for reconnect timing.
- Explicit `disconnect()` should stop reconnect intent.

## Task List

- [x] Add tests for OTA query mapping with `module` and `isActive` options.
- [x] Add tests verifying OTA list behavior remains unchanged when new filters are not provided.
- [x] Add tests for `OtaFile` typed date parsing (`releaseDate`, `createdDate`) including invalid/missing date handling.
- [x] Implement `module` and `isActive` in `OtaFilesListOptions` and query forwarding in `OtaFilesClient.list(...)`.
- [x] Implement additive typed date fields in `OtaFile` with safe parsing and backward compatibility.
- [ ] Add tests for proactive token refresh behavior using JWT expiry with a 12-hour window.
- [ ] Add tests for optional `onTokenUpdated` callback invocation when token changes.
- [ ] Add tests for `401` invalidation and exactly one retry per request.
- [ ] Add tests proving repeated `401` does not create retry loops.
- [ ] Add `InvalidatableAccessTokenProvider` and implement invalidation in `DeviceAuth`.
- [ ] Add optional `onTokenUpdated` callback to `DeviceAuthCallbacks` and wire invocation into token update paths.
- [ ] Implement authorized-request `401` invalidation + single retry behavior in shared HTTP helpers.
- [ ] Add tests for LiveData connect timeout behavior and timeout enforcement.
- [ ] Add tests for automatic reconnect on unexpected disconnect.
- [ ] Add tests verifying reconnect attempts resolve current token each attempt.
- [ ] Add tests verifying explicit `disconnect()` disables reconnect intent.
- [ ] Implement `connectTimeout` support in LiveData transport connection flow.
- [ ] Implement LiveData reconnect loop using shared backoff strategy and explicit stop semantics.
- [ ] Run `just test` and confirm all new and existing tests pass.
- [ ] Run `just lint` and confirm analyzer/lint checks pass.
- [ ] Add/update DartDoc comments for all newly introduced public fields, callbacks, and interfaces.
- [ ] Verify no breaking changes to existing public API usage patterns.
