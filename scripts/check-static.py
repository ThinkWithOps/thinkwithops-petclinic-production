#!/usr/bin/env python3
"""Check the normalized Compose model and source metadata without a daemon."""
import ast
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        sys.exit(f"FAIL: {message}")


def main():
    if sys.argv[1:] == ["--help"]:
        print("Usage: docker compose ... config --format json | python3 scripts/check-static.py")
        return
    require(not sys.argv[1:], "Unknown argument")
    config = json.load(sys.stdin)
    services = config["services"]
    require(set(services) == {"app", "postgres", "nginx"}, "Unexpected Compose services")
    for name in ("nginx", "postgres"):
        require(re.search(r"@sha256:[a-f0-9]{64}$", services[name]["image"]), f"Unpinned {name}")
    for name in ("app", "postgres"):
        require(not services[name].get("ports"), f"Host port exposed: {name}")
    for name in ("app", "nginx"):
        require(services[name]["read_only"], f"Writable root: {name}")
        require(services[name]["cap_drop"] == ["ALL"], f"Capabilities retained: {name}")
    require(services["app"]["depends_on"]["postgres"]["condition"] == "service_healthy", "DB ordering")
    require(services["nginx"]["depends_on"]["app"]["condition"] == "service_healthy", "App ordering")
    require(config["networks"]["backend"]["internal"], "Backend is not internal")
    require(not set(services["nginx"]["networks"]) & set(services["postgres"]["networks"]), "Proxy can reach DB network")
    require(services["app"]["environment"]["SPRING_PROFILES_ACTIVE"] == "postgres", "Wrong profile")
    properties = (ROOT / "src/main/resources/application-postgres.properties").read_text()
    for key in ("POSTGRES_URL", "POSTGRES_USER", "POSTGRES_PASS"):
        require("${" + key + ":" in properties, f"Upstream env contract changed: {key}")
        require(key in services["app"]["environment"], f"Missing env: {key}")
    dockerfile = (ROOT / "docker/Dockerfile").read_text()
    for line in dockerfile.splitlines():
        if line.startswith("FROM "):
            require(re.search(r"@sha256:[a-f0-9]{64}(?: AS \w+)?$", line), "Unpinned Docker base")
    pom = ET.parse(ROOT / "pom.xml")
    ns = {"m": "http://maven.apache.org/POM/4.0.0"}
    require(pom.findtext("m:properties/m:java.version", namespaces=ns) == "17", "Review Java image version")
    require(pom.findtext("m:parent/m:version", namespaces=ns) == "4.1.0", "Review Boot extraction")
    for path in (ROOT / "src/checkstyle").glob("*.xml"):
        ET.parse(path)
    for path in (ROOT / "scripts").glob("*.py"):
        ast.parse(path.read_text(), filename=str(path))
    print("PASS: Compose topology, digest pins, source configuration contract, XML and Python syntax")


if __name__ == "__main__":
    main()
