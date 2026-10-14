# Self-hosted CI: Jenkins + SonarQube + Nexus

Step-by-step setup for the stack in `ci/compose.yaml`. Run it on any Linux Docker
host you control: a laptop, a VM or a cloud instance. The GitHub Actions path
([`docs/ci-setup.md`](ci-setup.md)) needs none of this.

> **Status:** implementation prepared; end-to-end runtime verification pending.
> Treat the "expected" results below as the acceptance criteria, not as recorded output.

## Ports

| Service | Default port | Setting in `ci/.env` | Open it at | What for |
|---|---|---|---|---|
| Jenkins | `8090` | `JENKINS_PORT` | `http://<host>:8090` | Pipeline UI, credentials, build logs |
| SonarQube | `9000` | `SONARQUBE_PORT` | `http://<host>:9000` | Code quality gate, token, webhook |
| Nexus | `8081` | `NEXUS_PORT` | `http://<host>:8081` | Versioned JAR repository |
| Jenkins agent | `50000` | `JENKINS_AGENT_PORT` | not used | No remote agents in this stack |

- `<host>` is `localhost` when the browser runs on the Docker host itself. From
  another machine use the host's IP or DNS name, and make sure the three ports
  above are reachable (firewall, security group, or your host provider's port settings).
- **Port already in use?** The V1 app stack defaults to `8080` (nginx) and this stack
  uses `8081` for Nexus. If both run on one host, move one of them before the first start:

  ```bash
  export NEXUS_PORT=8083        # or: HTTP_PORT=8082 in docker/.env for the V1 app
  ./scripts/ci-stack-up.sh
  ```

  Use `export` (not an edit of `ci/.env`) before the first run: the script generates
  passwords only when `ci/.env` does not exist yet.
- Inside the Compose network the services reach each other by name:
  `http://sonarqube:9000`, `http://nexus:8081`, `http://jenkins:8080`. Those internal
  URLs never change, whatever host ports you chose.

## Requirements

- Linux Docker host with Docker Engine, Compose v2 and Buildx, plus `git`, `curl`, `python3`
- About 6 GB or more free RAM (SonarQube and Nexus are heavy)
- `vm.max_map_count >= 262144` on the host, for SonarQube's embedded Elasticsearch:

  ```bash
  sudo sysctl -w vm.max_map_count=262144
  ```

- Read/write access to `/var/run/docker.sock` (Jenkins drives the host Docker daemon)
- Outbound internet to `get.jenkins.io`, `updates.jenkins.io`, Docker Hub, GHCR and Maven Central

### Windows + Docker Desktop + WSL2

For local Windows use, install Docker Desktop and an Ubuntu WSL2 distribution.
In Docker Desktop, open **Settings -> Resources -> WSL Integration** and enable
the Ubuntu distribution. Allocate about 8 GB RAM to Docker Desktop. Launch
Ubuntu once and create its Linux username/password.

Run these checks inside the Ubuntu terminal:

```bash
docker info
docker compose version
docker buildx version
python3 --version
free -h
```

Clone into the Linux filesystem instead of `/mnt/c` or `/mnt/d`; this avoids
slow bind-mount I/O and Windows file-mode problems:

```bash
cd ~
git clone https://github.com/ThinkWithOps/thinkwithops-petclinic-production.git
cd thinkwithops-petclinic-production
sudo sysctl -w vm.max_map_count=262144
./scripts/ci-stack-up.sh 2>&1 | tee ~/ci-stack-up.log
```

Open Jenkins, SonarQube, and Nexus from the Windows browser at
`http://localhost:8090`, `http://localhost:9000`, and
`http://localhost:8081`. Continue with the same setup sections below. Docker
Desktop is suitable for local validation; use a managed or dedicated Linux
Docker host for an enduring shared deployment.

## 1. Start the stack

```bash
git clone https://github.com/ThinkWithOps/thinkwithops-petclinic-production.git
cd thinkwithops-petclinic-production
./scripts/ci-stack-up.sh 2>&1 | tee ci-stack-up.log
```

The first run builds the Jenkins image (plugins, Docker CLI, Trivy, Checkov, ShellCheck)
and takes several minutes. It creates `ci/.env` with random passwords (mode `0600`,
never committed), records the Docker socket's group ID as `DOCKER_GID`, and records
the Docker engine bridge gateway as `DOCKER_HOST_GATEWAY`. Jenkins uses that gateway
to reach database ports published by tests on the host daemon. This explicit mapping
also avoids Docker Desktop routing `host.docker.internal` outside its Linux engine.

Check it:

```bash
ci() { docker compose --env-file ci/.env -f ci/compose.yaml "$@"; }
ci ps
```

Expected: `jenkins`, `sonarqube-db`, `sonarqube` and `nexus` all `healthy`. SonarQube and
Nexus need 2-4 minutes. Wait for it:

```bash
for i in $(seq 1 40); do
  bad=$(ci ps --format '{{.Name}} {{.Health}}' | grep -vcx '.* healthy' || true)
  [ "$bad" -eq 0 ] && break; sleep 15
done
ci ps --format 'table {{.Name}}\t{{.Status}}'
```

Read the Jenkins admin login (do not paste this file anywhere):

```bash
grep -E '^(JENKINS_ADMIN_USER|JENKINS_PORT)=' ci/.env
grep '^JENKINS_ADMIN_PASSWORD=' ci/.env | cut -d= -f2
```

## 2. Log in to Jenkins

1. Open `http://<host>:8090`.
2. Sign in with `JENKINS_ADMIN_USER` / `JENKINS_ADMIN_PASSWORD` from `ci/.env`.
3. Confirm the seeded job exists: the dashboard must list **`petclinic-ci`**.
4. Confirm the SonarQube server entry: **Manage Jenkins -> System**, scroll to
   **SonarQube servers**. It must show **`local-sonarqube`** at `http://sonarqube:9000`.
   (The credential field there will be empty until step 6; that is expected.)

## 3. SonarQube: password, project, token

1. Open `http://<host>:9000`. Sign in `admin` / `admin`, then set a new password when asked.
2. **Create a project -> Manually**:
   - Project display name: `petclinic`
   - Project key: `ThinkWithOps_thinkwithops-petclinic-production`
     (must equal `sonar.projectKey` in `pom.xml`; if you forked, use the value from your `pom.xml`)
   - Main branch: `main`
3. On **Set up project for Clean as You Code**, keep **Use the global setting**
   with **Previous version**, then create the project.
4. On "How do you want to analyze your repository?" choose **Locally**. You do not need
   the snippet it generates; the Jenkinsfile runs the analysis.
5. **Create the token**: avatar (top right) -> **My Account -> Security -> Generate Tokens**.
   Name `jenkins`, type **User token**, then **Generate**. Copy it now. It is shown once.
6. Check it works (replace the placeholder, then unset):

   ```bash
   SONAR_TOKEN='<paste token>'
   curl -s -u "$SONAR_TOKEN:" http://localhost:9000/api/authentication/validate   # {"valid":true}
   curl -s http://localhost:9000/api/system/status                                # "status":"UP"
   unset SONAR_TOKEN
   ```

## 4. SonarQube webhook (required)

SonarQube -> **Administration -> Configuration -> Webhooks -> Create**:

| Field | Value |
|---|---|
| Name | `jenkins` |
| URL | `http://jenkins:8080/sonarqube-webhook/` |
| Secret | leave empty |

- Keep the trailing slash.
- Use `jenkins:8080` (Compose service name and the container's internal port), **not**
  `localhost:8090` or your host's public address. SonarQube calls Jenkins from inside
  the Compose network.
- Without this webhook, the `quality gate wait` stage sits until its 5-minute timeout
  and fails.

## 5. Nexus: password, repository, deploy user

1. Read the one-time admin password:

   ```bash
   ci exec nexus cat /nexus-data/admin.password; echo
   ```

2. Open `http://<host>:8081` -> **Sign in** as `admin` with that password. The setup
   wizard forces a new password. Choosing **Disable anonymous access** is fine.
3. **Settings (gear) -> Repository -> Repositories**: confirm the hosted
   **`maven-releases`** repository exists (Version policy `Release`).
   Its **Deployment policy** is `Disable redeploy` by default, so one version can be
   published exactly once. A second pipeline run on the same version fails at the last
   stage with `does not allow updating asset`. That is Nexus working as configured.
4. **Security -> Roles -> Create role -> Nexus role**. Create:
   - Role ID: `jenkins-maven-releases-deploy`
   - Role name: `Jenkins Maven Releases Deploy`
   - Privileges:
     - `nx-repository-view-maven2-maven-releases-add`
     - `nx-repository-view-maven2-maven-releases-browse`
     - `nx-repository-view-maven2-maven-releases-read`
     - `nx-repository-view-maven2-maven-releases-edit`
5. **Security -> Users -> Create local user**:
   - ID: `jenkins-deploy`
   - First name: `Jenkins`
   - Last name: `Deploy`
   - Email: `jenkins-deploy@localhost`
   - Password: choose and confirm a strong password
   - Status: `Active`
   - Granted role: `jenkins-maven-releases-deploy`
6. Do not grant `nx-admin`; Jenkins needs repository deployment access, not
   full Nexus administration.
7. Check it works:

   ```bash
   curl -s -o /dev/null -w '%{http_code} (expect 200)\n' http://localhost:8081/service/rest/v1/status
   curl -s -o /dev/null -w '%{http_code} (expect 200 or 404, not 401/403)\n' \
     -u 'jenkins-deploy:<password>' http://localhost:8081/repository/maven-releases/
   ```

## 6. Jenkins credentials

In Jenkins: **Manage Jenkins -> Credentials -> System -> Global credentials
(unrestricted) -> Add Credentials**.

Create the SonarQube credential:

- Kind: `Secret text`
- Secret: token created in step 3
- ID: `SONAR_TOKEN_LOCAL`
- Description: `Local SonarQube token`

Create the Nexus credential:

- Kind: `Username with password`
- Username: `jenkins-deploy`
- Password: password created for `jenkins-deploy` in Nexus
- ID: `NEXUS_DEPLOY_CREDENTIALS`
- Description: `Nexus Maven releases deployment`

IDs are case-sensitive. Do not use Nexus `admin` or the Jenkins administrator
account for `NEXUS_DEPLOY_CREDENTIALS`.

## 7. Run the pipeline

Jenkins -> **`petclinic-ci` -> Build Now**, then open the build -> **Console Output**
(or **Pipeline Overview**). The job reads the `Jenkinsfile` from the `main` branch of
`https://github.com/ThinkWithOps/thinkwithops-petclinic-production.git`. If you forked,
change that URL in `ci/jenkins/casc.yaml` and restart Jenkins first.

Expected stage order:

| # | Stage | Pass means |
|---|---|---|
| 1 | `prepare` | Prints the commit SHA |
| 2 | `verify` | `./mvnw verify` green; prints a `sha256` for the JAR |
| 3 | `sonar (local)` | Analysis uploaded to `http://sonarqube:9000` |
| 4 | `quality gate wait` | Returns within a minute or two with the gate PASSED (needs the step 4 webhook) |
| 5 | `image build` | Image built on the host daemon and saved as `image.tar` |
| 6 | `trivy` | No fixable CRITICAL vulnerabilities; `trivy-results.sarif` written |
| 7 | `checkov + shellcheck` | Both exit 0 |
| 8 | `sbom` | `sbom.cdx.json` written |
| 9 | `deploy JAR to Nexus` | `sha256sum -c` prints `OK`, then the JAR is uploaded |

## 8. Verify the results

- **Jenkins build page -> Build Artifacts** lists `target/spring-petclinic-*.jar`,
  `target/verified-jar.sha256`, `trivy-results.sarif` and `sbom.cdx.json`.
- **SonarQube -> Projects -> petclinic** shows the analysis and the quality gate result.
- **Nexus -> Browse -> `maven-releases`** shows
  `org/springframework/samples/spring-petclinic/<version>/spring-petclinic-<version>.jar`.
- Webhook delivery: SonarQube -> Administration -> Configuration -> Webhooks shows the
  last delivery as `Success` (HTTP 200).

Prove Nexus received the exact JAR tested by Jenkins:

```bash
JU=$(grep '^JENKINS_ADMIN_USER=' ci/.env | cut -d= -f2)
JP=$(grep '^JENKINS_ADMIN_PASSWORD=' ci/.env | cut -d= -f2)
JPORT=$(grep '^JENKINS_PORT=' ci/.env | cut -d= -f2); JPORT=${JPORT:-8090}
read -rp 'Nexus deploy username: ' NEXUS_USER
read -rsp 'Nexus deploy password: ' NEXUS_PASSWORD; echo
V=$(sed -n 's|.*<version>\(.*\)</version>.*|\1|p' pom.xml | sed -n 2p)

curl -s -u "$NEXUS_USER:$NEXUS_PASSWORD" -o /tmp/nexus.jar \
  "http://localhost:8081/repository/maven-releases/org/springframework/samples/spring-petclinic/$V/spring-petclinic-$V.jar"
sha256sum /tmp/nexus.jar
curl -s -u "$JU:$JP" \
  "http://localhost:$JPORT/job/petclinic-ci/lastSuccessfulBuild/artifact/target/verified-jar.sha256"
unset NEXUS_PASSWORD
```

Pass: both SHA-256 values match exactly.

## 9. Stop

```bash
./scripts/ci-stack-up.sh --down
```

Volumes are kept. Run `ci down --volumes` only if you want to delete SonarQube, Nexus and
Jenkins state.

## If something fails

See [`docs/troubleshooting.md`](troubleshooting.md). The common ones:

| Symptom | Fix |
|---|---|
| `ERROR: Install python3 before continuing.` | Install `python3` on the host and re-run `./scripts/ci-stack-up.sh`. |
| `sonarqube` restarts in a loop | `sudo sysctl -w vm.max_map_count=262144` on the host. |
| `permission denied ... /var/run/docker.sock` inside Jenkins | `DOCKER_GID` in `ci/.env` must equal `stat -c '%g' /var/run/docker.sock`. |
| PostgreSQL test says `password authentication failed for user "petclinic"` only inside Jenkins | Re-run `./scripts/ci-stack-up.sh`; it refreshes `DOCKER_HOST_GATEWAY` from the Docker `bridge` network and recreates Jenkins with the correct host route. |
| `quality gate wait` times out | Webhook missing or wrong URL (step 4). |
| Jenkins build fails on a plugin | A pinned version in `ci/jenkins/plugins.txt` needs a different Jenkins core; see troubleshooting. |
| `bind: address already in use` | Another service owns the port; set `JENKINS_PORT`, `SONARQUBE_PORT` or `NEXUS_PORT` before the first run. |
