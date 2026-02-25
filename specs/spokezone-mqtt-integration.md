---
number: 3
status: approved
author: Addison Emig
creation_date: 2026-02-24
approved_by: Addison Emig
approval_date: 2026-02-25
---

# Spoke.Zone MQTT Integration

Add first-class MQTT live-data support to the Flutter SDK by extending `SpokeZone` with `liveData`.

This integration builds on [Spoke.Zone API Integration](spokezone-api-integration.md) and must work with whichever auth mode the `SpokeZone` instance is using. The initial scope is publish-focused and supports one-off JSON publishes plus scheduled periodic publishing for device telemetry.

## Design Decisions

### Public API Shape

- Chosen: Add `SpokeZone.liveData` with type `LiveData`
  - Keeps MQTT behavior colocated with the existing `SpokeZone` root service
  - Avoids introducing a second top-level service object
- Chosen: Current scope is publish-focused (no subscribe API yet)
  - Keep the public API focused while preserving internal flexibility for future subscriptions

### Auth and Service Integration

- Chosen: `LiveData` uses the same active auth provider already configured in `SpokeZone`
  - No separate MQTT auth configuration on public APIs
  - Token acquisition for connect/reconnect asks the auth provider for the current token
- Chosen: Reconnect uses the same shared backoff helper types defined in [Spoke.Zone API Integration](spokezone-api-integration.md): `BackoffStrategy` + default `FixedDelayBackoffStrategy`
  - Ensures one retry/backoff strategy system across HTTP and MQTT concerns

### MQTT Configuration

- Chosen: MQTT connection settings are owned by `SpokeZoneConfig`
  - `mqttHost`, `mqttPort`, `mqttUseTls`
  - Defaults: `mqttHost = io.spoke.zone`, `mqttPort = 8883`, `mqttUseTls = true`
- Chosen: Unencrypted MQTT (`mqttPort = 1883`, `mqttUseTls = false`) is supported for testing only

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
- Chosen: one-off `publishJson` failures do not expose additional global diagnostics in public API
- Chosen: periodic publishing failures do not throw into loop callers
  - Scheduler continues running and reports failure through per-registration status

### Fixed Topics and Helpers

- Chosen: Keep fixed SDK topic conventions for predefined Spoke.Zone messages
  - Location topic: `mrs/d/<device-id>/mon/location`
  - Software versions topic: `mrs/d/<device-id>/mon/versions`
- Chosen: Fixed-topic payload contracts are explicit
  - Location helper accepts `Coordinates` and serializes MQTT payload as `{lat, lon}`
  - Software versions helper accepts flat `Map<String, String>` (`module -> version`)
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

- Chosen: Per-registration status uses a minimal contract
  - States: `idle`, `running`, `failed`, `canceled`
  - Fields: `lastSuccessAt`, `consecutiveFailures`
- Chosen: Cancel transitions status to terminal `canceled`

## Task List

### API Surface and Wiring

- [ ] Add tests first for `SpokeZone.liveData` exposure and type contract.
- [ ] Add tests first for `LiveData` lifecycle API (`connect`, `disconnect`, `isConnected`) and initial disconnected state.
- [ ] Add tests first for MQTT config defaults and overrides via `SpokeZoneConfig` (`mqttHost`, `mqttPort`, `mqttUseTls`), including test-only unencrypted mode.
- [ ] Implement `SpokeZone.liveData` and lifecycle API wiring to satisfy tests.

### Auth and Connection Behavior

- [ ] Add tests first that connect/reconnect asks the active `SpokeZone` auth provider for the current token.
- [ ] Add tests first for reconnect behavior using shared `BackoffStrategy` and default `FixedDelayBackoffStrategy`.
- [ ] Implement auth-driven connect/reconnect behavior using shared `BackoffStrategy` and `FixedDelayBackoffStrategy` types from API integration (no MQTT-specific duplicate backoff types).

### Publish Contract

- [ ] Add tests first for `publishJson(topic, payload)` success/failure boolean semantics.
- [ ] Add tests first for payload validation and serialization behavior.
- [ ] Implement `publishJson` behavior with non-throwing boolean outcomes.

### Periodic Broadcasting

- [ ] Add tests first for generic periodic registration API with custom topic strings and async nullable callbacks.
- [ ] Add tests first for scheduler timing semantics: no immediate publish on registration, first publish on first interval tick, and subsequent publishes on configured cadence.
- [ ] Add tests first for cancellation/resume semantics: cancel stops only that registration, `disconnect()` pauses active registrations, and later `connect()` resumes uncanceled registrations.
- [ ] Add tests first for `registerLocationBroadcast(...)` fixed topic, default interval behavior, and `Coordinates -> {lat, lon}` payload serialization.
- [ ] Add tests first for `registerSoftwareVersionsBroadcast(...)` fixed topic, default interval behavior, and flat `Map<String, String>` payload contract.
- [ ] Implement generic periodic scheduler and registration handles.
- [ ] Implement helper registration methods using the generic periodic scheduler.

### Per-Registration Status

- [ ] Add tests first for minimal status fields and state transitions per registration (`state`, `lastSuccessAt`, `consecutiveFailures`).
- [ ] Implement minimal status tracking surface on registration handles.

### Documentation

- [ ] Update `docs/src/content/docs/index.mdx` and `docs/astro.config.mjs` so the Spoke.Zone docs set includes `spoke-zone/live-data` in docs navigation and index listings.
- [ ] Update `docs/src/content/docs/spoke-zone/index.mdx` to link to `live-data.mdx` as part of the canonical Spoke.Zone docs set.
- [ ] Update `docs/src/content/docs/spoke-zone/live-data.mdx` with the implemented `SpokeZone.liveData` public API signatures: lifecycle methods (`connect`, `disconnect`, `isConnected`), `publishJson`, generic periodic registration, and helper registrations.
- [ ] Update `docs/src/content/docs/spoke-zone/live-data.mdx` with periodic registration behavior: async-nullable callback contract, first-publish-on-first-tick timing, cancellation semantics, reconnect resume behavior, default helper intervals, and fixed topics.
- [ ] Update `docs/src/content/docs/spoke-zone/live-data.mdx` with per-registration status contract (`idle`, `running`, `failed`, `canceled`; `lastSuccessAt`; `consecutiveFailures`) and auth/reconnect behavior using shared `BackoffStrategy` and `FixedDelayBackoffStrategy`.
