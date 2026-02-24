---
number: 2
status: draft
author: Addison Emig
creation_date: 2026-02-24
---

# Spoke.Zone API Integration

Add a first-class Spoke.Zone API client to the Flutter SDK so applications can integrate with Spoke.Zone device workflows without re-implementing HTTP, auth, retries, and error mapping.

This v1 scope is device-first and includes:

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

- Chosen: `SpokeZoneService` always receives one `SpokeZoneConfig`
  - `SpokeZoneConfig.device(...)` for device mode
  - `SpokeZoneConfig.user(...)` for user mode
  - Exactly one mode is valid per config instance
- Chosen: No auth scope parameter in API
  - Mode is selected by which named constructor built the config
- Chosen: One shared auth interface type implemented by both device and user auth providers
  - A single provider instance on a given config generates `x-access-token` for all requests in that mode

### Auth Provider Contracts

- Chosen: `DeviceAuth.login` owns `/loginDevice` token renewal flow
  - `SpokeZoneService` does not orchestrate login itself
  - Device auth implementation handles token lifecycle internally
- Chosen: `SpokeZoneConfig.device(...)` requires async callbacks for
  - `cpuId`
  - `uuid`
  - `deviceId`
  - `initialDeviceToken`
- Chosen: `SpokeZoneConfig.user(...)` requires async callbacks for
  - `username`
  - `password`

### Data and Download Semantics

- Chosen: Strongly typed models with only documented guaranteed fields
  - Unknown fields are discarded in v1
- Chosen: `dataFiles.upload(id, content)` accepts raw bytes only
  - No filename or MIME arguments in v1
- Chosen: `otaFiles.download(id)` returns raw bytes
  - SDK does not write files to disk

### Retry and Backoff

- Chosen: Built-in retry defaults (not configurable in v1)
  - Retry on transport errors, `429`, and `5xx`
  - Do not retry other `4xx`
  - Retry schedule: `15s`, `30s`, `60s`
  - Same policy applies to `DeviceAuth.login`
- Chosen: Backoff strategy abstraction
  - Define a backoff interface with one default implementation
  - Keep call sites stable if strategy changes later

### Error System

- Chosen: Stable typed SDK error codes as public contract
  - Initial codes: `unauthorized`, `forbidden`, `notFound`, `rateLimited`, `serverError`, `networkError`, `validationError`, `unsupportedAuthMode`
- Chosen: Every SDK error includes diagnostics
  - `endpoint`
  - `httpStatus` when present
  - bounded response-body snippet

## Endpoint Contracts (v1)

Source of truth for this section is Spoke.Zone published API documentation and access-token documentation as of 2026-02-24.

### `POST /loginDevice` (DeviceAuth.login)

| Item                             | Contract                                                              |
| -------------------------------- | --------------------------------------------------------------------- |
| Auth header                      | none                                                                  |
| Request body                     | JSON object with `token` (string), `cpu_id` (string), `uuid` (string) |
| Success status                   | `200` or `201`                                                        |
| Success body (guaranteed fields) | `token` (string)                                                      |
| Error statuses to map            | `400`, `401`, `403`, `429`, `5xx`                                     |

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

### `GET /api/v2/ota-files` (otaFiles.list)

| Item                                      | Contract                                                                                                                                                                                      |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth header                               | `x-access-token: <token>`                                                                                                                                                                     |
| Query params                              | Supports documented pagination/search/sort/filter params (`searchTerm`, `searchFields`, `sort`, `sortOrder`, `limit`, `offset`)                                                               |
| Success status                            | `200`                                                                                                                                                                                         |
| Success body (guaranteed fields per item) | `id` (number), `modelId` (number), `moduleId` (number), `module` (string), `version` (string), `fileLocation` (string), `isActive` (boolean), `createdDate` (string), `releaseNotes` (string) |
| Error statuses to map                     | `400`, `401`, `403`, `429`, `5xx`                                                                                                                                                             |

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

Note: only documented and explicitly selected fields above are modeled in v1. Additional API fields are intentionally ignored.

## Task List

### Foundation

- [ ] Add tests first for `SpokeZoneConfig.device(...)` and `SpokeZoneConfig.user(...)` construction rules (exactly one auth mode per config)
- [ ] Add tests first for shared auth interface usage in both modes and `x-access-token` request decoration
- [ ] Implement config and auth mode plumbing to make foundation tests pass
- [ ] Cleanup pass: improve config/auth API clarity and structure without changing behavior

### Device and User Auth

- [ ] Add tests first for `DeviceAuth.login` request/response/error mapping for `POST /loginDevice`
- [ ] Add tests first for user-mode credential callback handling (`username`, `password`) and token lifecycle entry points
- [ ] Implement auth providers and callbacks to make auth tests pass
- [ ] Cleanup pass: align auth lifecycle flow and remove duplicated token-handling logic without changing behavior

### Service Shape

- [ ] Add tests first asserting root `SpokeZoneService` exposes `devices`, `dataFiles`, and `otaFiles` namespaces
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
- [ ] Add tests first for typed error code mapping and diagnostic context (`endpoint`, `httpStatus`, bounded response snippet)
- [ ] Implement retry/backoff and uniform error mapping to make reliability tests pass
- [ ] Cleanup pass: centralize retry and error mapping policies into shared components without changing behavior

### Documentation

- [ ] Add API docs for `SpokeZoneConfig.device(...)` and `SpokeZoneConfig.user(...)` with callback requirements
- [ ] Add docs for `DeviceAuth.login` ownership and token lifecycle responsibilities
- [ ] Add docs for endpoint contracts, typed error codes, and fixed retry/backoff defaults
