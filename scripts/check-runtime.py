#!/usr/bin/env python3
"""Validate docker inspect JSON from stdin. Called by validate-local.sh."""
import json
import sys


def require(condition, message):
    if not condition:
        sys.exit(f"FAIL: {message}")


def main():
    if sys.argv[1:] == ["--help"]:
        print("Usage: docker inspect APP NGINX POSTGRES | python3 scripts/check-runtime.py")
        return
    require(not sys.argv[1:], "Unknown argument")
    app, nginx, postgres = json.load(sys.stdin)
    for container in (app, postgres):
        bindings = container["HostConfig"].get("PortBindings") or {}
        require(not any(bindings.values()), "Application/database port published on host")
    app_nets = set(app["NetworkSettings"]["Networks"])
    proxy_nets = set(nginx["NetworkSettings"]["Networks"])
    db_nets = set(postgres["NetworkSettings"]["Networks"])
    require(not proxy_nets & db_nets, "Nginx shares a database network")
    require(bool(app_nets & proxy_nets) and bool(app_nets & db_nets), "App network connectivity missing")
    for container, uid in ((app, "10001"), (nginx, "101")):
        require(container["Config"]["User"].split(":")[0] == uid, "Unexpected runtime user")
        host = container["HostConfig"]
        require(host["ReadonlyRootfs"], "Writable root filesystem")
        require("ALL" in [cap.upper() for cap in host.get("CapDrop") or []], "Capabilities not dropped")
        require(any("no-new-privileges" in s for s in host.get("SecurityOpt") or []), "Privilege escalation allowed")
        require(host["Memory"] > 0, "Memory limit missing")
    env = dict(entry.split("=", 1) for entry in app["Config"]["Env"])
    require(env.get("SPRING_PROFILES_ACTIVE") == "postgres", "PostgreSQL profile not active")
    require(env.get("POSTGRES_URL", "").startswith("jdbc:postgresql://postgres:5432/"), "Unexpected DB URL")
    require(app["Config"]["Entrypoint"] == ["java", "-jar", "application.jar"], "JVM is not direct entrypoint")
    print("PASS: network isolation, unpublished app/DB ports, hardening, PostgreSQL config, exec entrypoint")


if __name__ == "__main__":
    main()
