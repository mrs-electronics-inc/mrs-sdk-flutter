---
number: 2
status: in-progress
author: Addison Emig
creation_date: 2026-02-24
approved_by: Addison Emig
approval_date: 2026-02-25
---

# Spoke.Zone API Integration

Add a first-class Spoke.Zone API client to the Flutter SDK so applications can integrate with Spoke.Zone device workflows without re-implementing HTTP, auth, retries, and error mapping.

This scope is device-first and includes:

- `DeviceAuth.login` via `POST /loginDevice`
- Data file lifecycle via `POST /api/v2/data-files` and `POST /api/v2/data-files/{id}/file`
- OTA retrieval via `GET /api/v2/ota-files` and `GET /api/v2/ota-files/{id}/file`
- Device details via `GET /api/v2/devices/{id}`

The SDK must remain forward-compatible with user-token endpoint families.

## Design Decisions

### Public API Shape

- Chosen: One root `SpokeZone` with capability namespaces
  - Public API: `spokeZone.devices.get(...)`, `spokeZone.dataFiles.create(...)`, `spokeZone.dataFiles.upload(...)`, `spokeZone.otaFiles.list(...)`, `spokeZone.otaFiles.download(...)`
  - Keeps API discoverable and scalable as endpoint families grow
- Considered: Single flat service with all methods
  - Simpler initially
  - Harder to scale and maintain

### Configuration and Auth Mode

See: `docs/src/content/docs/spoke-zone/config.mdx`

- Chosen: `SpokeZone` always receives one `SpokeZoneConfig`
  - `SpokeZoneConfig.device(...)` for device mode
  - `SpokeZoneConfig.user(...)` for user mode
  - Exactly one mode is valid per config instance
- Chosen: No auth scope parameter in API
  - Mode is selected by which named constructor built the config
- Chosen: One shared auth interface type implemented by both device and user auth providers
  - A single provider instance on a given config generates `x-access-token` for all requests in that mode
- Chosen: Base URL hosts, callback semantics, and environment rules are documented in the config docs page and treated as canonical reference during implementation.

### Auth Provider Contracts

See: `docs/src/content/docs/spoke-zone/auth.mdx`

- Chosen: `DeviceAuth.login` owns `/loginDevice` token renewal flow
  - `SpokeZone` does not orchestrate login itself
  - Device auth implementation handles token lifecycle internally
- Chosen: `UserAuth.login` owns user token acquisition and renewal flow
  - `SpokeZone` does not orchestrate user login itself
  - User auth implementation handles token lifecycle internally
- Chosen: Shared request pipeline ownership is centralized in `SpokeZone`
  - Request serialization, headers, retry/backoff, and error mapping are service-owned
  - Auth providers are responsible only for token lifecycle and credential callbacks
- Chosen: Exact callback requirements and behavior are documented in the auth/config docs pages and treated as canonical reference during implementation.

### Data and Download Semantics

- Chosen: Strongly typed models with only documented guaranteed fields
  - Unknown fields are discarded
- Chosen: `dataFiles.upload(id, content)` accepts raw bytes only
  - No filename or MIME arguments
- Chosen: `otaFiles.download(id)` returns raw bytes
  - SDK does not write files to disk

### Retry and Backoff

- Chosen: Built-in retry defaults (not configurable)
  - Retry on transport errors, `429`, and `5xx`
  - Do not retry other `4xx`
  - Retry schedule: `15s`, `30s`, `60s`
  - Same policy applies to `DeviceAuth.login` and `UserAuth.login`
- Chosen: Backoff strategy abstraction
  - Define a backoff interface with one default implementation
  - Keep call sites stable if strategy changes later
- Chosen: Retry policy details live in the retry docs page and are treated as canonical reference during implementation.

### Error System

See: `docs/src/content/docs/spoke-zone/errors.mdx`

- Chosen: Stable typed SDK error codes as public contract
  - Initial codes: `unauthorized`, `forbidden`, `notFound`, `rateLimited`, `serverError`, `networkError`, `validationError`, `unsupportedAuthMode`, `retryLimitReached`, `unknown`
- Chosen: SDK uses one typed public error surface with deterministic mapping behavior; full field-level/error-mapping reference is maintained in the errors docs page.

## Internal Docs

Implementation-facing docs for this integration live in:

- `docs/src/content/docs/spoke-zone/index.mdx`
- `docs/src/content/docs/spoke-zone/config.mdx`
- `docs/src/content/docs/spoke-zone/auth.mdx`
- `docs/src/content/docs/spoke-zone/errors.mdx`
- `docs/src/content/docs/spoke-zone/retry.mdx`
- `docs/src/content/docs/spoke-zone/endpoints.mdx`

## Endpoint Contracts

See: `docs/src/content/docs/spoke-zone/endpoints.mdx`

All request/response, default/query, and endpoint-specific error mapping details are maintained in the docs page above. During implementation, treat that docs page as the canonical endpoint contract reference and keep it updated alongside code changes.

## Task List

### Foundation

- [x] Add tests first for `SpokeZoneConfig.device(...)` and `SpokeZoneConfig.user(...)` construction rules (exactly one auth mode per config)
- [x] Add tests first for shared auth interface usage in both modes and `x-access-token` request decoration
- [x] Implement config and auth mode plumbing to make foundation tests pass
- [x] Refactor config/auth construction for readability while preserving behavior; verify foundation tests remain green

### Device and User Auth

- [x] Add tests first for `DeviceAuth.login` request/response/error mapping for `POST /loginDevice`
- [x] Add tests first for `UserAuth.login` credential callback handling (`username`, `password`) and token lifecycle entry points
- [x] Add tests first for `UserAuth.login` failure mapping and retry behavior parity with `DeviceAuth.login`
- [x] Implement auth providers and callbacks to make auth tests pass
- [x] Remove duplicated token-handling logic by extracting shared auth lifecycle helpers; verify auth tests remain green

### Service Shape

- [x] Add tests first asserting root `SpokeZone` exposes `devices`, `dataFiles`, and `otaFiles` namespaces
- [x] Add tests first for shared HTTP pipeline behavior (header injection, retry orchestration, and error mapping middleware)
- [x] Implement root service and namespaced clients to make service-shape tests pass
- [x] Simplify service wiring by extracting shared request setup into one internal helper; verify service-shape tests remain green

### Endpoint Behavior

- [x] Add tests first for `devices.get(id)` typed mapping: `name -> modelName`, `lastOnline` parse-to-null on missing/invalid, `lastLocation` null when either coordinate missing, and `softwareVersions` defaulting to empty map
- [x] Add tests first for shared `Coordinates` model usage in `devices.get(id)` (`lastLocation` typed as `Coordinates?` when both values are present)
- [x] Add tests first for `dataFiles.create(type)` using allowed type values and `id` extraction
- [x] Add tests first for `dataFiles.upload(id, content)` multipart construction from raw bytes
- [x] Add tests first for `otaFiles.list(...)` query handling and typed item mapping
- [x] Add tests first for `otaFiles.download(id)` byte-return behavior
- [ ] Implement endpoint clients to make endpoint tests pass
- [ ] Extract shared request/response helpers used by `devices`, `dataFiles`, and `otaFiles`; verify endpoint-behavior tests remain green

### Reliability and Errors

- [ ] Add tests first for retry policy: transport errors + `429` + `5xx` with delay sequence `15s -> 30s -> 60s`
- [ ] Add tests first for non-retriable behavior on `4xx` other than `429`
- [ ] Add tests first for backoff abstraction behavior via interface + default implementation
- [ ] Implement shared backoff helper types (`BackoffStrategy` interface and default `FixedDelayBackoffStrategy`) and wire them into retry orchestration
- [ ] Add tests first for typed error code mapping and diagnostic context (`endpoint`, `httpStatus`, bounded response snippet, retry metadata)
- [ ] Add tests first that public APIs throw only SDK-typed exceptions (no raw HTTP/client exceptions leak)
- [ ] Add tests first for client-side `validationError` mapping before request dispatch
- [ ] Implement retry/backoff and uniform error mapping to make reliability tests pass
- [ ] Centralize retry and error-mapping policy wiring into shared internal components; verify reliability/error tests remain green

### Documentation

- [ ] Update `docs/src/content/docs/spoke-zone/config.mdx` to document config mode constructors, base URL host rules, and callback semantics for both auth modes
- [ ] Update `docs/src/content/docs/spoke-zone/auth.mdx` to document `DeviceAuth.login` and `UserAuth.login` lifecycle ownership and callback contracts
- [ ] Update `docs/src/content/docs/spoke-zone/errors.mdx` to list all public SDK error codes and their mapping/diagnostic behavior
- [ ] Update `docs/src/content/docs/spoke-zone/retry.mdx` to document retryable status classes, non-retryable classes, and `15s -> 30s -> 60s` delay sequence
- [ ] Update `docs/src/content/docs/spoke-zone/endpoints.mdx` with request/response contracts for `devices.get`, `dataFiles.create`, `dataFiles.upload`, `otaFiles.list`, and `otaFiles.download`
- [ ] Update `docs/src/content/docs/spoke-zone/index.mdx` to link to config/auth/errors/retry/endpoints pages and avoid duplicating endpoint contracts
- [ ] Update `docs/src/content/docs/index.mdx` and `docs/astro.config.mjs` so Spoke.Zone docs are listed in site navigation and docs index
