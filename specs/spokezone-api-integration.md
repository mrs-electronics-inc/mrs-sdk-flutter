---
number: 2
status: draft
author: Addison Emig
creation_date: 2026-02-24
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

- Chosen: One root `SpokeZoneService` with capability namespaces
  - Public API: `spokeZone.devices.get(...)`, `spokeZone.dataFiles.create(...)`, `spokeZone.dataFiles.upload(...)`, `spokeZone.otaFiles.list(...)`, `spokeZone.otaFiles.download(...)`
  - Keeps API discoverable and scalable as endpoint families grow
- Considered: Single flat service with all methods
  - Simpler initially
  - Harder to scale and maintain

### Configuration and Auth Mode

See: `docs/src/content/docs/spoke-zone/config.mdx`

- Chosen: `SpokeZoneService` always receives one `SpokeZoneConfig`
  - `SpokeZoneConfig.device(...)` for device mode
  - `SpokeZoneConfig.user(...)` for user mode
  - Exactly one mode is valid per config instance
- Chosen: Base URL and environment are explicit config concerns
  - Default base URL is `https://api.spoke.zone`
  - Config supports explicit base URL override for non-production environments
  - All endpoint and auth calls use the same configured base URL
  - SDK does not provision environment credentials; host applications provide secrets via config callbacks
- Chosen: No auth scope parameter in API
  - Mode is selected by which named constructor built the config
- Chosen: One shared auth interface type implemented by both device and user auth providers
  - A single provider instance on a given config generates `x-access-token` for all requests in that mode

### Auth Provider Contracts

See: `docs/src/content/docs/spoke-zone/auth.mdx`

- Chosen: `DeviceAuth.login` owns `/loginDevice` token renewal flow
  - `SpokeZoneService` does not orchestrate login itself
  - Device auth implementation handles token lifecycle internally
- Chosen: `UserAuth.login` owns user token acquisition and renewal flow
  - `SpokeZoneService` does not orchestrate user login itself
  - User auth implementation handles token lifecycle internally
- Chosen: `SpokeZoneConfig.device(...)` requires async callbacks for
  - `cpuId`
  - `uuid`
  - `deviceId`
  - `initialDeviceToken`
- Chosen: `SpokeZoneConfig.user(...)` requires async callbacks for
  - `username`
  - `password`
- Chosen: Shared request pipeline ownership is centralized in `SpokeZoneService`
  - Request serialization, headers, retry/backoff, and error mapping are service-owned
  - Auth providers are responsible only for token lifecycle and credential callbacks
- Chosen: Credential/identity callback contract is strict
  - Callbacks are invoked on-demand during auth and may be re-invoked for retries
  - Callback failures propagate into SDK auth/error handling (they are not swallowed)
  - Callbacks must not return `null`; null-like states are represented as thrown errors
  - Callback implementations may cache values, but cache freshness is provider-owned
  - Callback execution uses the same operation timeout budget as the requesting auth flow

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

### Error System

See: `docs/src/content/docs/spoke-zone/errors.mdx`

- Chosen: Stable typed SDK error codes as public contract
  - Initial codes: `unauthorized`, `forbidden`, `notFound`, `rateLimited`, `serverError`, `networkError`, `validationError`, `unsupportedAuthMode`, `retryLimitReached`, `unknown`
- Chosen: Every SDK error includes diagnostics
  - `endpoint`
  - `httpStatus` when present
  - bounded response-body snippet
- Chosen: SDK exposes a single public exception/error shape for all failures
  - `code`: typed error code
  - `message`: SDK-provided summary
  - `endpoint`: relative endpoint path
  - `httpStatus`: nullable status code
  - `responseSnippet`: bounded response fragment when present
  - `retryAttempt`: nullable attempt index for retry-related failures
  - `retryAfter`: nullable delay for rate-limited/retry flows
- Chosen: Consumer-observable behavior is deterministic
  - Public methods throw SDK-typed exceptions only (never raw HTTP/client exceptions)
  - Transport/timeout exceptions map to `networkError` with `httpStatus = null`
  - Client-side contract violations map to `validationError` before network call
  - Retry exhaustion maps to `retryLimitReached` with last failure diagnostics attached

## Internal Docs

Implementation-facing docs for this integration live in:

- `docs/src/content/docs/spoke-zone/index.mdx`
- `docs/src/content/docs/spoke-zone/config.mdx`
- `docs/src/content/docs/spoke-zone/auth.mdx`
- `docs/src/content/docs/spoke-zone/errors.mdx`
- `docs/src/content/docs/spoke-zone/endpoints.mdx`

## Endpoint Contracts

See: `docs/src/content/docs/spoke-zone/endpoints.mdx`

Source of truth for this section is Spoke.Zone published documentation as of 2026-02-24:

- API docs: https://api.spoke.zone/api-docs
- Access token docs: https://docs.spoke.zone/developers/general-api-usage/access-tokens/

### `POST /loginDevice` (DeviceAuth.login)

| Item                             | Contract                                                              |
| -------------------------------- | --------------------------------------------------------------------- |
| Auth header                      | none                                                                  |
| Request body                     | JSON object with `token` (string), `cpu_id` (string), `uuid` (string) |
| Success status                   | `200` or `201`                                                        |
| Success body (guaranteed fields) | `token` (string)                                                      |
| Error statuses to map            | `400`, `401`, `403`, `429`, `5xx`                                     |

### `UserAuth.login` (user authentication flow)

| Item                  | Contract                                                                 |
| --------------------- | ------------------------------------------------------------------------ |
| Responsibility        | Obtain and refresh user `x-access-token` from `username` and `password` |
| Service behavior      | `SpokeZoneService` consumes tokens from `UserAuth` and does not call login endpoints directly |
| Trigger conditions    | Initial user-token acquisition and subsequent refresh/reauth as needed |
| Error statuses to map | `400`, `401`, `403`, `429`, `5xx`                                        |

### `POST /api/v2/data-files` (dataFiles.create)

| Item                             | Contract                                                                                         |
| -------------------------------- | ------------------------------------------------------------------------------------------------ |
| Auth header                      | `x-access-token: <token>`                                                                        |
| Request body                     | JSON object with `type` (string enum: `log`, `event`, `gps`, `debug`, `journal`, `dmesg`, `txt`) |
| Success status                   | `200`                                                                                            |
| Success body (guaranteed fields) | `id` (number)                                                                                    |
| Error statuses to map            | `400`, `401`, `403`, `429`, `5xx`                                                                |

### `POST /api/v2/data-files/{id}/file` (dataFiles.upload)

| Item                             | Contract                                                             |
| -------------------------------- | -------------------------------------------------------------------- |
| Auth header                      | `x-access-token: <token>`                                            |
| Path params                      | `id` (number)                                                        |
| Request body                     | `multipart/form-data` with `files` (binary) populated from raw bytes |
| Success status                   | `200`                                                                |
| Success body (guaranteed fields) | none required by SDK                                                 |
| Error statuses to map            | `400`, `401`, `403`, `429`, `5xx`                                    |

Upload semantics:

- Input is fully buffered bytes (`Uint8List`), encoded as multipart field `files`
- SDK does not provide chunked upload in this scope
- SDK retries per global retry policy; caller controls higher-level concurrency

### `GET /api/v2/ota-files` (otaFiles.list)

| Item                                      | Contract                                                                                                                                                                                      |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth header                               | `x-access-token: <token>`                                                                                                                                                                     |
| Query params                              | Supports documented pagination/search/sort/filter params (`searchTerm`, `searchFields`, `sort`, `sortOrder`, `limit`, `offset`)                                                               |
| Success status                            | `200`                                                                                                                                                                                         |
| Success body (guaranteed fields per item) | `id` (number), `modelId` (number), `moduleId` (number), `module` (string), `version` (string), `fileLocation` (string), `isActive` (boolean), `createdDate` (string), `releaseNotes` (string) |
| Error statuses to map                     | `400`, `401`, `403`, `429`, `5xx`                                                                                                                                                             |

List defaults:

- When omitted by caller: `limit=50`, `offset=0`
- Caller-provided query values override defaults

### `GET /api/v2/ota-files/{id}/file` (otaFiles.download)

| Item                  | Contract                              |
| --------------------- | ------------------------------------- |
| Auth header           | `x-access-token: <token>`             |
| Path params           | `id` (number)                         |
| Success status        | `200`                                 |
| Success body          | binary file content returned as bytes |
| Error statuses to map | `400`, `401`, `403`, `429`, `5xx`     |

### `GET /api/v2/devices/{id}` (devices.get)

| Item                             | Contract                                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth header                      | `x-access-token: <token>`                                                                                                                                                                                                                                                                                                                                                  |
| Path params                      | `id` (number)                                                                                                                                                                                                                                                                                                                                                              |
| Success status                   | `200`                                                                                                                                                                                                                                                                                                                                                                      |
| Success body (SDK model mapping) | `id` (number), `identifier` (string), `serialNumber` (string), `modelId` (number), `modelName` (string, mapped from API field `name`), `lastOnline` (`DateTime?`, null when missing/invalid), `lastLocation` (`{ latitude: double, longitude: double }?`, null when either coordinate is missing), `softwareVersions` (`Map<String, String>`, empty map when missing/null) |
| Error statuses to map            | `400`, `401`, `403`, `404`, `429`, `5xx`                                                                                                                                                                                                                                                                                                                                   |

Note: only documented and explicitly selected fields above are modeled. Additional API fields are intentionally ignored.

## Task List

### Foundation

- [ ] Add tests first for `SpokeZoneConfig.device(...)` and `SpokeZoneConfig.user(...)` construction rules (exactly one auth mode per config)
- [ ] Add tests first for shared auth interface usage in both modes and `x-access-token` request decoration
- [ ] Implement config and auth mode plumbing to make foundation tests pass
- [ ] Cleanup pass: improve config/auth API clarity and structure without changing behavior

### Device and User Auth

- [ ] Add tests first for `DeviceAuth.login` request/response/error mapping for `POST /loginDevice`
- [ ] Add tests first for `UserAuth.login` credential callback handling (`username`, `password`) and token lifecycle entry points
- [ ] Add tests first for `UserAuth.login` failure mapping and retry behavior parity with `DeviceAuth.login`
- [ ] Implement auth providers and callbacks to make auth tests pass
- [ ] Cleanup pass: align auth lifecycle flow and remove duplicated token-handling logic without changing behavior

### Service Shape

- [ ] Add tests first asserting root `SpokeZoneService` exposes `devices`, `dataFiles`, and `otaFiles` namespaces
- [ ] Add tests first for shared HTTP pipeline behavior (header injection, retry orchestration, and error mapping middleware)
- [ ] Implement root service and namespaced clients to make service-shape tests pass
- [ ] Cleanup pass: simplify service wiring and shared request setup without changing behavior

### Endpoint Behavior

- [ ] Add tests first for `devices.get(id)` typed mapping: `name -> modelName`, `lastOnline` parse-to-null on missing/invalid, `lastLocation` null when either coordinate missing, and `softwareVersions` defaulting to empty map
- [ ] Add tests first for `dataFiles.create(type)` using allowed type values and `id` extraction
- [ ] Add tests first for `dataFiles.upload(id, content)` multipart construction from raw bytes
- [ ] Add tests first for `otaFiles.list(...)` query handling and typed item mapping
- [ ] Add tests first for `otaFiles.download(id)` byte-return behavior
- [ ] Implement endpoint clients to make endpoint tests pass
- [ ] Cleanup pass: extract shared request/response helpers without changing behavior

### Reliability and Errors

- [ ] Add tests first for retry policy: transport errors + `429` + `5xx` with delay sequence `15s -> 30s -> 60s`
- [ ] Add tests first for non-retriable behavior on `4xx` other than `429`
- [ ] Add tests first for backoff abstraction behavior via interface + default implementation
- [ ] Add tests first for typed error code mapping and diagnostic context (`endpoint`, `httpStatus`, bounded response snippet, retry metadata)
- [ ] Add tests first that public APIs throw only SDK-typed exceptions (no raw HTTP/client exceptions leak)
- [ ] Add tests first for client-side `validationError` mapping before request dispatch
- [ ] Implement retry/backoff and uniform error mapping to make reliability tests pass
- [ ] Cleanup pass: centralize retry and error mapping policies into shared components without changing behavior

### Documentation

- [ ] Update `docs/src/content/docs/spoke-zone/config.mdx` so config modes, base URL rules, and callback contracts match implementation behavior
- [ ] Update `docs/src/content/docs/spoke-zone/auth.mdx` so `DeviceAuth.login` and `UserAuth.login` lifecycle ownership matches implementation behavior
- [ ] Update `docs/src/content/docs/spoke-zone/errors.mdx` so typed error codes, diagnostics, and consumer-observable behavior match implementation behavior
- [ ] Update `docs/src/content/docs/spoke-zone/endpoints.mdx` so endpoint contracts and query/default semantics match implementation behavior
- [ ] Update `docs/src/content/docs/spoke-zone/index.mdx` hub links/content to match implemented Spoke.Zone docs structure
- [ ] Update docs discoverability entry points to include the Spoke.Zone doc hub
