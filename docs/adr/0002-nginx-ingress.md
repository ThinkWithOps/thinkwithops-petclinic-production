# ADR 0002: one unprivileged reverse proxy

Status: accepted; runtime checks pending.

## Problem and options

The app needs one controlled HTTP entrypoint. Publishing the app directly is simpler; Nginx adds request limits, centralized headers and management-path denial. A cloud load balancer is unnecessary for a local Compose milestone.

## Decision

Use digest-pinned Nginx unprivileged, UID/GID 101, port 8080, read-only root, writable bounded `/tmp`, and only the frontend network. Its independent health endpoint is `/nginx-health`. Docker DNS resolves the app after container replacement. Host header includes the external port; forwarding headers are replaced to prevent spoofed client input. Timeouts, gzip and a 1 MiB request limit are explicit.

The internal Alpine entrypoint uses POSIX `sh` with `set -eu`, because this image has no Bash. User-facing automation uses Bash and `set -euo pipefail`. `envsubst` replaces **only** `PUBLIC_SCHEME`; all Nginx variables remain intact. The generated config and PID/temp files live in `/tmp`, and `nginx -t` runs before exec.

## Trade-offs

An extra container consumes resources. HTTP inside the host remains cleartext. Default scheme is `http`; when a trusted front proxy terminates HTTPS, set `PUBLIC_SCHEME=https`. Do not forward client-supplied `X-Forwarded-Proto` blindly. This option does not enable TLS at Nginx. Some front-proxy authentication/iframe behavior can only be tested against a real remote host.

## Enterprise scale

Terminate TLS with managed certificates at an ingress/load balancer, restrict trusted proxy sources, add request/rate policies from measured traffic and explicitly define client-IP propagation across each trusted hop.
