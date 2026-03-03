## 0.3.0

- Add `SpokeZone.liveData` MQTT integration for publish-focused live-data workflows.
- Add explicit live-data lifecycle APIs (`connect`, `disconnect`, `isConnected`) with shared auth/backoff reconnect behavior.
- Add `publishJson(...)` with retained-message support and non-throwing boolean delivery results.
- Add periodic broadcasting APIs for custom topics plus fixed helpers for location and software versions.
- Add per-registration observability (`state`, `lastSuccessAt`, `consecutiveFailures`) and live-data usage docs.

## 0.2.0

- Implement basic Spoke.Zone integration.

## 0.1.0

- Prepare first automated GitHub Actions publish flow.

## 0.0.1

- Scaffolded initial Flutter package structure.
