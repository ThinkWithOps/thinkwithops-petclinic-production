# ADR 0003: private health endpoints, no public actuator

Status: accepted; runtime checks pending.

## Problem and options

Upstream sets `management.endpoints.web.exposure.include=*` for development. Keeping all endpoints public would expose unnecessary operational information. We could modify application properties, expose a second management port or override configuration externally.

## Decision

Keep application source intact. Compose overrides exposure to `health`, disables details and explicitly enables probes outside Kubernetes. Readiness includes `db`; liveness checks process health without a database dependency. BusyBox `wget` probes containers directly. Nginx returns 404 for `/actuator`, descendants and semicolon variants.

## Trade-offs

Health is visible to workloads sharing the app network, and Docker host administrators retain full access. This is layered exposure reduction, not endpoint authentication. The validation script checks normalized/encoded path variants as well as ordinary paths; future server upgrades require repeating these checks.

## Enterprise scale

Use authenticated management access, monitoring network policies and a separate management listener where appropriate. Expose only endpoints required by actual monitoring consumers; never restore `*` for convenience.
