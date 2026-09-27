# ADR 0001: layered Temurin JRE and a measured size budget

Status: accepted stock-JRE design; **measured 2026-09-27: 249,667,151 bytes (~238 MiB) — exceeds the 200 MB budget.** See `docs/validation/v1-containerized.md` §2 for the full `docker history` breakdown. The `jlink` follow-up below is the accepted next step, not yet built.

## Problem

Build a reproducible Java 17 runtime around the upstream Spring Boot 4.1.0 application without shipping Maven, a compiler, caches or source in the final image. The target is below 200,000,000 uncompressed bytes.

## Options

1. Full JDK: simple diagnostics but a larger runtime and unnecessary compiler tooling.
2. Temurin JRE Alpine: stock Java compatibility, BusyBox healthcheck support and a smaller base.
3. A `jdeps`/`jlink` custom runtime: fewer modules, but reflective/framework code needs additional module validation and ongoing maintenance.

## Decision

Use Maven's Java 17 build image pinned by digest, but execute `./mvnw` so the repository controls Maven (3.9.16). BuildKit caches `/root/.m2`; copy the POM and wrapper before application source. Image builds skip tests; full tests belong in the subsequent CI milestone and the V1 pre-release regression checklist.

Use the stock Java 17 Alpine JRE pinned by digest; fixed UID/GID 10001; direct `java -jar application.jar` entrypoint. Boot's `tools` extraction produces an optimized application jar and separate dependency, loader, snapshot and application layers. See [Spring Boot's Dockerfile guide](https://docs.spring.io/spring-boot/reference/packaging/container-images/dockerfiles.html).

`build.sh` and `verify.sh` report `docker image inspect .Size` and full `docker history`. This is uncompressed engine size, not registry transfer size or disk space uniquely occupied. Record architecture and digest with measurements.

## Trade-offs and size gate

The selected Alpine JRE manifest supports Linux amd64; scripts reject other engine architectures. Musl compatibility, extracted jar startup and actual memory usage remain runtime checks.

If the stock image exceeds the target, do not claim the budget passed. Before V1 release, add and test an optional custom-runtime target: use a digest-pinned musl JDK 17, run `jdeps --multi-release 17 --print-module-deps` against extracted app/dependency jars, supplement modules needed via reflection/services, run `jlink --strip-debug --no-header-files --no-man-pages`, then compare size/history and the **full** verification suite. A glibc-linked runtime cannot simply be copied into Alpine. No unmeasured size reduction or untested `jlink` image is represented as working here.

## Enterprise scale

Use automated digest updates, SBOM/vulnerability gates, signed images, a controlled registry and multi-architecture validation. Consider a custom JRE only when its measured savings justify ownership of compatibility testing.
