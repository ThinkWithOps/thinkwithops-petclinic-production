# Troubleshooting — V1 containerized runtime

Only failure modes that genuinely arise from this architecture. Format: symptom → likely cause → how to diagnose → fix.

---

### `docker compose up` / `deploy.sh` fails with "Missing .env"

**Cause:** `docker/.env` doesn't exist yet; it's gitignored on purpose (never commit real secrets).

**Diagnose:** `ls docker/.env`

**Fix:** run `./scripts/setup-playground.sh` (also called automatically by `deploy.sh`). It copies `docker/.env.example` → `docker/.env`, mode 0600, and replaces the two `REPLACE_WITH_RANDOM_*_PASSWORD` placeholders with real random secrets.

---

### `app` container never becomes healthy; stuck behind `postgres`

**Cause:** Compose's `depends_on: condition: service_healthy` is working as designed — the app won't even start until Postgres's `pg_isready` healthcheck passes.

**Diagnose:** `docker compose -f docker/compose.yaml ps` — check which service is still `starting`/`unhealthy`. `docker compose -f docker/compose.yaml logs postgres`.

**Fix:** usually just needs more time (Postgres cold start + init script). If it never recovers, check `docker/postgres/init-app-user.sh` output in the Postgres logs for SQL errors.

---

### App healthcheck fails with "wget: not found" or similar

**Cause:** the runtime image is Alpine — there is no `curl`, only BusyBox `wget`. If someone edits the Dockerfile's `HEALTHCHECK` to use `curl`, it will always fail.

**Diagnose:** `docker inspect <app-container> --format '{{json .State.Health}}'`

**Fix:** keep the healthcheck as `wget -q -O /dev/null http://127.0.0.1:8080/actuator/health/liveness` (already how `docker/Dockerfile` is written).

---

### App reachable directly on 8080 but actuator/health probes report `DOWN` or app never becomes ready

**Cause:** `MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED` is only auto-enabled by Spring Boot when it detects it's running on Kubernetes. In plain Docker, it must be set explicitly.

**Diagnose:** `docker exec <app-container> env | grep MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED`

**Fix:** confirm it's `true` in `docker/compose.yaml`'s `app.environment` (it already is) — this only breaks if that line is removed or the env var name is misspelled.

---

### App can't connect to PostgreSQL — "Connection refused" or datasource errors on startup

**Cause:** wrong env var names. The upstream `application-postgres.properties` reads specific placeholder names (`POSTGRES_URL`, `POSTGRES_USER`, `POSTGRES_PASS`) — if `docker/compose.yaml` doesn't set exactly those names, Spring silently falls back to defaults and fails to connect.

**Diagnose:** `grep -n 'POSTGRES_' src/main/resources/application-postgres.properties` and compare against `docker/compose.yaml`'s `app.environment`. `docker compose logs app` for the actual JDBC connection error.

**Fix:** the env var names must match exactly what the properties file interpolates — don't guess, always re-check `application-postgres.properties` after any upstream update.

---

### App gets OOMKilled under load

**Cause:** JVM heap (`-XX:MaxRAMPercentage=65.0`) plus native memory plus the `/tmp` tmpfs must all fit inside the container's `mem_limit`. If `APP_MEMORY_LIMIT` is lowered without also lowering the JVM percentage, the container gets killed by the kernel, not by the JVM's own OOM handling.

**Diagnose:** `docker inspect <app-container> --format '{{.State.OOMKilled}}'`; `docker stats` while under load.

**Fix:** keep `JAVA_TOOL_OPTIONS` and `APP_MEMORY_LIMIT` in `docker/.env` changed together — heap should stay well under the container limit, not up against it.

---

### Restarting the stack (`compose down && up`) seems to re-run database seed/init scripts

**Cause:** would only happen if the named `postgres-data` volume gets removed. Postgres only runs `docker-entrypoint-initdb.d/*` scripts (including `init-app-user.sh`) on a **fresh, empty** data directory — a plain `compose down` (no `-v`/`--volumes`) preserves the volume and skips them on the next `up`.

**Diagnose:** `docker volume ls | grep postgres-data` before and after; `docker compose logs postgres` — init script output only appears on first-ever start.

**Fix:** if you actually want a fresh database, use `./scripts/cleanup.sh --purge-data` explicitly rather than relying on a bare `down`.

---

### `/actuator/health` or other actuator paths are reachable from outside

**Cause:** something bypassed Nginx (e.g. a published port on the `app` service), or the `location ~* ^/actuator(?:/|;|$) { return 404; }` block in `docker/nginx/conf.d/petclinic.conf` was edited/removed.

**Diagnose:** `docker compose config` — confirm `app` has no `ports:` entry. `curl -i http://<nginx-host>:<port>/actuator/health` — must be 404, not the real payload. Also try the encoded variant `/%61ctuator/health` and the semicolon variant `/actuator;x/health` — Tomcat/Spring can normalize these differently than a naive Nginx rule.

**Fix:** app/postgres must never get a `ports:` mapping in `docker/compose.yaml`; keep the case-insensitive regex location block in the Nginx config, and re-run `./scripts/verify.sh` (checks all of the above paths) after any Nginx config change.

---

### Playground's port viewer can't reach the app

**Cause:** `BIND_ADDRESS` in `docker/.env` defaults to `127.0.0.1` (loopback-only), which is correct for a real workstation but invisible to a lab's external port viewer.

**Diagnose:** `docker compose config` — check the `nginx.ports` binding.

**Fix:** set `BIND_ADDRESS=0.0.0.0` in `docker/.env` before running `./scripts/deploy.sh` in the playground (the scripts remind you of this).

---

### Playground session expires mid-demo

**Cause:** cloud playground labs are ephemeral (~2–3 hours) by design — this is not a bug in this repo.

**Fix:** nothing to fix; re-provision a new playground and re-run `./scripts/deploy.sh` — the whole flow is idempotent and safe to rerun against a fresh lab. Data does not survive playground destruction (only survives `compose down && up` within the same session) — this is documented, not a defect.
