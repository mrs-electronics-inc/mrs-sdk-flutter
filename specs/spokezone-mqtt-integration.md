---
number: 3
status: draft
author: Addison Emig
creation_date: 2026-02-24
---

# Spoke.Zone MQTT Integration

Add first-class MQTT live-data support to the Flutter SDK by extending `SpokeZone` with `liveData`.

This integration builds on [Spoke.Zone API Integration](spokezone-api-integration.md) and must work with whichever auth mode the `SpokeZone` instance is using. The initial scope is publish-focused and supports one-off JSON publishes plus scheduled periodic publishing for device telemetry.

## Design Decisions

### Public API Shape

- Chosen: Add `SpokeZone.liveData` with type `LiveData`
  - Keeps MQTT behavior colocated with the existing `SpokeZone` root service
  - Avoids introducing a second top-level service object
- Chosen: V1 is publish-only (no subscribe API)
  - Keep the public API focused while preserving internal flexibility for future subscriptions

### Auth and Service Integration

- Chosen: `LiveData` uses the same active auth provider already configured in `SpokeZone`
  - No separate MQTT auth configuration on public APIs
  - Token acquisition for connect/reconnect asks the auth provider for the current token
- Chosen: Reconnect uses the same shared backoff helper types defined in [Spoke.Zone API Integration](spokezone-api-integration.md): `BackoffStrategy` + default `FixedDelayBackoffStrategy`
  - Ensures one retry/backoff strategy system across HTTP and MQTT concerns

### Connection Lifecycle and State

- Chosen: Explicit lifecycle methods are required
  - `connect()`
  - `disconnect()`
  - `isConnected` observable state
- Chosen: Periodic jobs do not run before `connect()`
- Chosen: On `disconnect()`, periodic jobs pause; on later `connect()`, existing registrations automatically resume

### Publish Contract

- Chosen: `publishJson(...)` accepts `Map<String, dynamic>` payloads and returns `Future<bool>`
  - `true` means publish succeeded
  - `false` means not delivered (for example disconnected and reconnect not yet successful)
  - Callers decide strictness by handling the boolean return value
- Chosen: periodic publishing failures do not throw into loop callers
  - Scheduler continues running and reports failure through status/logging surfaces

### Fixed Topics and Helpers

- Chosen: Keep fixed SDK topic conventions for predefined Spoke.Zone messages
  - Location topic: `mrs/d/<device-id>/mon/location`
  - Software versions topic: `mrs/d/<device-id>/mon/versions`
- Chosen: Expose both generic and convenience registration APIs
  - Generic periodic registration supports any custom topic string
  - Helper methods exist for location and software-version broadcasting using fixed topics and SDK default intervals
- Chosen: Default helper intervals are fixed
  - Location: every 15 seconds
  - Software versions: every 60 seconds

### Periodic Registration Model

- Chosen: Periodic callbacks are async and nullable
  - Signature equivalent to `Future<Map<String, dynamic>?>`
  - `null` means skip this tick without publishing
- Chosen: First publish occurs on first interval tick (not immediately on registration)
- Chosen: Registrations return a cancellable handle
  - Canceling one registration does not disconnect MQTT or stop other registrations

### Per-Registration Observability

- Chosen: Per-registration status is required in V1
- Chosen: Status model includes both lifecycle state and diagnostics
  - States: `idle`, `running`, `failed`, `canceled`
  - Fields: `lastAttemptAt`, `lastSuccessAt`, `consecutiveFailures`, `lastError`, `lastPublished`
- Chosen: Cancel transitions status to terminal `canceled`

## Task List

### API Surface and Wiring

- [ ] Add tests first for `SpokeZone.liveData` exposure and type contract.
- [ ] Add tests first for `LiveData` lifecycle API (`connect`, `disconnect`, `isConnected`) and initial disconnected state.
- [ ] Implement `SpokeZone.liveData` and lifecycle API wiring to satisfy tests.

### Auth and Connection Behavior

- [ ] Add tests first that connect/reconnect asks the active `SpokeZone` auth provider for the current token.
- [ ] Add tests first for reconnect behavior using shared `BackoffStrategy` and default `FixedDelayBackoffStrategy`.
- [ ] Implement auth-driven connect/reconnect behavior and shared `BackoffStrategy`/`FixedDelayBackoffStrategy` integration.

### Publish Contract

- [ ] Add tests first for `publishJson(topic, payload)` success/failure boolean semantics.
- [ ] Add tests first for payload validation and serialization behavior.
- [ ] Implement `publishJson` behavior and typed error mapping.

### Periodic Broadcasting

- [ ] Add tests first for generic periodic registration API with custom topic strings and async nullable callbacks.
- [ ] Add tests first for scheduler timing semantics.
- [ ] Add tests first for cancellation and resume semantics.
- [ ] Add tests first for `registerLocationBroadcast(...)` fixed topic and default interval behavior.
- [ ] Add tests first for `registerSoftwareVersionsBroadcast(...)` fixed topic and default interval behavior.
- [ ] Implement generic periodic scheduler and registration handles.
- [ ] Implement helper registration methods using the generic periodic scheduler.

### Per-Registration Status and Diagnostics

- [ ] Add tests first for required status fields and state transitions per registration.
- [ ] Add tests first for diagnostic field updates on success/failure.
- [ ] Implement status/diagnostic tracking surface on registration handles.

### Documentation

- [ ] Update the Spoke.Zone docs index and related pages to include the Live Data contract page in the canonical Spoke.Zone docs set.
- [ ] Fill `docs/src/content/docs/spoke-zone/live-data.mdx` with finalized public API signatures that match the implemented `SpokeZone.liveData` surface.
- [ ] Fill `docs/src/content/docs/spoke-zone/live-data.mdx` with finalized periodic registration semantics, default helper intervals, fixed topic conventions, and typed `Coordinates` usage for location broadcasting.
- [ ] Fill `docs/src/content/docs/spoke-zone/live-data.mdx` with finalized per-registration status state/field contracts and reconnect/auth behavior using shared `BackoffStrategy` and `FixedDelayBackoffStrategy`.
