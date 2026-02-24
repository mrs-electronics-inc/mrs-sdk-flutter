---
number: 2
status: draft
author: Addison Emig
creation_date: 2026-02-24
---

# Spoke.Zone API Integration

Add a first-class Spoke.Zone API client to the Flutter SDK so applications can integrate with Spoke.Zone device workflows without re-implementing HTTP, auth, retries, and error mapping.

This spec targets a device-first v1 surface area based on existing production usage:

- Device login/token renewal via `POST /loginDevice`
- Data file lifecycle via `POST /api/v2/data-files` and `POST /api/v2/data-files/{id}/file`
- OTA retrieval via `GET /api/v2/ota-files` and `GET /api/v2/ota-files/{id}/file`
- Device details via `GET /api/v2/devices/{id}`

The design also needs to avoid an API dead-end. While v1 is device-focused, the SDK should be structured so user-token endpoints can be added later without breaking the public API.

## Design Decisions

### Public API Shape

- Chosen: One root `SpokeZoneService` exposing capability namespaces
  - Public API follows `spokeZone.devices.get(...)`, `spokeZone.dataFiles.create(...)`, `spokeZone.dataFiles.upload(...)`, `spokeZone.otaFiles.list(...)`, and `spokeZone.otaFiles.download(...)`
  - Keeps app-facing API discoverable and consistent as more endpoint families are added
  - Avoids a flat class with many unrelated methods while still presenting a single integration entry point
- Considered: A single monolithic service class with all methods at top level
  - Simpler initial wiring
  - Scales poorly as endpoint count grows and concerns diverge
- Considered: Fully separate top-level clients only
  - Clear internal boundaries
  - Higher integration overhead for app developers compared with one root client

### Configuration Ownership

- Chosen: Dedicated `SpokeZoneConfig` owned by the Spoke.Zone integration
  - SDK currently has no global config/service abstraction to reuse
  - Keeps Spoke.Zone concerns isolated and explicit
  - Enables growth without coupling to unrelated SDK subsystems
- Considered: Reuse hypothetical global SDK config/service abstraction
  - Would reduce config duplication if such abstraction existed
  - Not applicable to current SDK architecture

### Auth Model for Future Compatibility

- Chosen: Auth provider abstraction that returns valid tokens by scope
  - `authProvider` owns token lifecycle (cache, refresh, re-auth) and service consumes valid tokens
  - Supports device scope now and user scope later without breaking config contracts
  - Keeps endpoint logic separate from token refresh orchestration
- Considered: Service-managed refresh flow with refresh callbacks in each API area
  - Keeps refresh logic near requests
  - Increases complexity and risks duplicated refresh behavior

### Error and Retry Behavior

- Chosen: Built-in retries for transient failures and a typed SDK error model
  - Retries with backoff for transient failures (network errors, `429`, and `5xx`)
  - SDK errors expose stable typed codes for deterministic app handling
  - Errors include HTTP context (status, endpoint, and bounded response snippet) for diagnostics
  - Aligns with existing app-level patterns that separate machine handling from user messaging
- Considered: No built-in retries (app handles all retries)
  - Maximum app control
  - Reintroduces duplicated reliability logic across integrators

## Task List

### Foundation

- [ ] Add tests first for `SpokeZoneConfig`, scoped auth provider contract, and device identity provider contract
- [ ] Implement `SpokeZoneConfig` and provider abstractions to make foundation tests pass
- [ ] Cleanup pass: improve config/provider API clarity and structure without changing behavior

### Service Shape

- [ ] Add tests first asserting root `SpokeZoneService` exposes `devices`, `dataFiles`, and `otaFiles` namespaces
- [ ] Implement root service and namespaced clients to make service-shape tests pass
- [ ] Cleanup pass: simplify service wiring and shared request setup without changing behavior

### Device Endpoint

- [ ] Add tests first for `devices.get(id)` request/response/error mapping for `GET /api/v2/devices/{id}`
- [ ] Implement `devices.get(id)` to make endpoint tests pass
- [ ] Cleanup pass: extract shared device response/error helpers without changing behavior

### Data Files Endpoints

- [ ] Add tests first for `dataFiles.create(type)` and `dataFiles.upload(id, content)` request construction, success parsing, and error mapping
- [ ] Implement `POST /api/v2/data-files` and `POST /api/v2/data-files/{id}/file` support to make tests pass
- [ ] Cleanup pass: consolidate multipart upload and request-building helpers without changing behavior

### OTA Endpoints

- [ ] Add tests first for `otaFiles.list(...)` and `otaFiles.download(id)` covering query usage, parsing, binary handling, and error mapping
- [ ] Implement `GET /api/v2/ota-files` and `GET /api/v2/ota-files/{id}/file` support to make tests pass
- [ ] Cleanup pass: extract OTA parsing/download helpers and remove duplication without changing behavior

### Login Device Endpoint

- [ ] Add tests first for `loginDevice` (`POST /loginDevice`) including token renewal response handling and failure mapping
- [ ] Implement device login/token renewal flow to make tests pass
- [ ] Cleanup pass: align auth-scoped request flow between login and endpoint clients without changing behavior

### Reliability and Errors

- [ ] Add tests first for retry/backoff behavior on transient failures (`429`, `5xx`, transport errors) and non-retriable exclusions
- [ ] Implement bounded retry/backoff policy in the HTTP pipeline to make tests pass
- [ ] Add tests first for typed SDK error codes and diagnostic context (`status`, endpoint, bounded response snippet)
- [ ] Implement uniform error mapping and context propagation across all endpoints
- [ ] Cleanup pass: centralize retry and error mapping policies into shared middleware/components without changing behavior

### Documentation

- [ ] Add usage docs for `SpokeZoneConfig`, auth provider responsibilities (including refresh ownership), and namespaced service APIs
- [ ] Add docs for retry policy, typed error model, and recommended app-level error handling
