# V1 validation: containerized PetClinic

Status: **verified 2026-09-27** on a real Docker engine (Ubuntu 24.04 amd64 Docker host). All checks below passed.

Run order:

```bash
./scripts/static-check.sh     # no Docker daemon required
./scripts/deploy.sh           # setup-env.sh + build.sh + run-local.sh
./scripts/verify.sh           # full functional + persistence checks (validate-local.sh)
./scripts/cleanup.sh          # tear down; --purge-data also drops the DB volume
```

## 1. Static checks (`static-check.sh`)

No daemon required.

| Check | Tool | Expected |
|---|---|---|
| Shell syntax | `bash -n` on every script | no output, exit 0 |
| Shell lint | `shellcheck -x` | no findings |
| Compose model is valid | `docker compose config --quiet` | no output, exit 0 |
| Compose topology matches spec | `check-static.py` | `PASS: Compose topology, digest pins, source configuration contract, XML and Python syntax` |

## 2. Image build (`build.sh`, via `deploy.sh`)

| Check | How | Expected |
|---|---|---|
| Image builds | `docker build ...` | exits 0 |
| Base images pinned | grep `FROM` lines | each ends `@sha256:<64 hex>` |
| Size measured, not assumed | `docker image inspect --format '{{.Size}}'` | printed bytes; script warns if ≥ 200,000,000 (budget from ADR 0001) |
| Per-layer breakdown recorded | `docker history --no-trunc` | printed to console — paste into this file after a real run |

**Recorded 2026-09-27 (Ubuntu 24.04 amd64 Docker host):**

- Image size: **249,667,151 bytes** (~238 MiB) — **exceeds the 200 MB budget** from ADR 0001.
- Largest layers: Temurin JRE download+extract 141 MB; `apk add` (fontconfig, gnupg, ca-certificates, tzdata, musl-locales, etc.) 34.9 MB; Alpine base rootfs 8.42 MB; dependency jars layer 65.1 MB; application layer 470 kB.
- Per ADR 0001: since the stock JRE exceeds budget, the optional `jlink` custom-runtime follow-up (jdeps-derived module set) should be evaluated before declaring V1 release-final — full `docker history` kept in git history of this file's commit for reference.

## 3. Runtime — container health (`verify.sh` → `healthy()`)

| Check | Expected |
|---|---|
| `postgres` container health | `healthy` |
| `app` container health | `healthy` |
| `nginx` container health | `healthy` |

Output: `PASS: all three containers healthy`

## 4. Network isolation and hardening (`check-runtime.py`, via `verify.sh`)

| Check | Expected |
|---|---|
| App has no published host port | no `PortBindings` |
| Postgres has no published host port | no `PortBindings` |
| Nginx and Postgres share no network | `frontend` ∩ Postgres networks = ∅ |
| App bridges both networks | app ∈ `frontend` and app ∈ `backend` |
| App/Nginx run non-root | `Config.User` = `10001` / `101` |
| Root filesystem read-only | `HostConfig.ReadonlyRootfs = true` |
| Capabilities dropped | `CapDrop` includes `ALL` |
| No privilege escalation | `SecurityOpt` includes `no-new-privileges` |
| Memory limit set | `HostConfig.Memory > 0` |
| PostgreSQL profile active | `SPRING_PROFILES_ACTIVE=postgres` |
| Correct JDBC URL | `jdbc:postgresql://postgres:5432/...` |
| Exec-form entrypoint | `Entrypoint == ["java", "-jar", "application.jar"]` |

Output: `PASS: network isolation, unpublished app/DB ports, hardening, PostgreSQL config, exec entrypoint`

## 5. HTTP surface (`verify.sh` → `http_checks()`)

| Check | Expected |
|---|---|
| PetClinic home page loads through Nginx | 200, body contains `PetClinic` |
| Nginx's own health endpoint | `/nginx-health` → `ok` |
| `/actuator`, `/actuator/health`, `/actuator/env`, `/actuator;test/health`, `/%61ctuator/health` | all → 404 through Nginx |

Output: `PASS: application reachable; actuator paths blocked`

## 6. Direct probe endpoints (`verify.sh`)

| Check | Expected |
|---|---|
| App liveness probe reachable inside the app container | `wget` to `/actuator/health/liveness` exits 0 |
| App readiness probe reachable inside the app container | `wget` to `/actuator/health/readiness` exits 0 |

Output: `PASS: non-root UIDs and direct probe endpoints`

## 7. PostgreSQL write/read/persistence (`verify.sh`, skipped with `--smoke-only`)

| Check | Expected |
|---|---|
| HTTP `POST /owners/new` creates a row | 302 redirect |
| Row exists in PostgreSQL | `SELECT` returns a numeric id |
| App reads it back through HTTP | probe marker text visible in `/owners/{id}` |
| App's DB role is not superuser | `rolsuper = false` |
| Data survives `compose down && up` | table row counts unchanged, probe owner still present |

Output: `PASS: HTTP write/read matches PostgreSQL row; app role is not superuser` and `PASS: persistence across down/up; no duplicate seed rows; app reads persisted data`

## 8. Optional external viewer smoke test

If `PUBLIC_URL` is set (e.g. a forwarded or public URL), `verify.sh` also fetches it directly and checks for `PetClinic` in the body. Useful to confirm the externally reachable proxy chain works end to end, separate from the internal `localhost` checks above.

## Definition of done for this milestone

- Every check above shows PASS from a clean clone, following only the README.
- Image size recorded in section 2 (with the per-layer breakdown), whether or not it beats the 200 MB budget — if it doesn't, ADR 0001's `jlink` follow-up is evaluated before tagging.
- `./scripts/cleanup.sh` leaves no running containers; `--purge-data` leaves no volume.
- Only then: tag `v1-containerized` and cut the GitHub Release.
