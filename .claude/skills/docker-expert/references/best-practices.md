# Docker Expert — Best Practices Reference

## Multi-Stage Build Pattern (Best Practice #1-2)

### Named stages and artifact copying

```dockerfile
# Stage 1: builder — has all build tools
FROM python:3.12 AS builder
WORKDIR /build

# Install build dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install build

COPY pyproject.toml ./
RUN python -m build --wheel

# Stage 2: final — minimal runtime only
FROM python:3.12-slim AS final
WORKDIR /app

# Copy only the wheel from builder, nothing else
COPY --from=builder /build/dist/*.whl ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install *.whl && rm *.whl

# Non-root user
RUN groupadd -r app && useradd --no-log-init -r -g app app
COPY --chown=app:app src/ ./src/
USER app

CMD ["python", "-m", "src.main"]
```

Use `--target builder` in CI to build only the builder stage for testing:
```bash
docker build --target builder -t myapp:test .
```

### Non-root user patterns

Alpine:
```dockerfile
RUN addgroup -g 1001 -S app && adduser -S app -u 1001 -G app
COPY --chown=app:app . .
USER app
```

Debian/Ubuntu-based:
```dockerfile
RUN groupadd -r app && useradd --no-log-init -r -g app -u 1001 app
COPY --chown=app:app . .
USER app
```

Use `--no-log-init` with `useradd` to avoid a Docker-specific issue with large
`/var/log/lastlog` entries. Always set explicit UID/GID (1001+) for
compatibility with Kubernetes `runAsUser` security contexts.

## Cache Mounts (Best Practice #3)

BuildKit cache mounts persist package manager caches between builds without
adding to image layers. This is the correct way to speed up dependency installs.

```dockerfile
# Python / pip
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Node.js / npm
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

# Node.js / yarn
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    yarn install --frozen-lockfile

# apt-get
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev
```

Cache mounts require BuildKit (`DOCKER_BUILDKIT=1` or Docker 23.0+). The cache
is local to the builder and is not stored in the image or pushed to a registry.

## Compose v2 Details (Best Practice #4)

Drop the `version:` field entirely (it was deprecated in Compose v2). Use
`docker compose` with a space, not `docker-compose` with a hyphen.

Full service dependency pattern:

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    environment:
      POSTGRES_USER: app
      POSTGRES_DB: appdb
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://app@db/appdb
```

`start_period` is critical for slow-starting services — healthcheck failures
during `start_period` don't count against `retries`.

## Health Checks (Best Practice #5)

Define in Dockerfile for self-contained images:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

For databases and services without `curl`:
```dockerfile
# PostgreSQL
HEALTHCHECK CMD pg_isready -U postgres || exit 1

# Redis
HEALTHCHECK CMD redis-cli ping | grep PONG || exit 1

# Generic TCP port check
HEALTHCHECK CMD nc -z localhost 8080 || exit 1
```

Prefer Compose `healthcheck:` over Dockerfile `HEALTHCHECK` when using Compose —
it's easier to override per-environment and doesn't bake interval settings
into the image.

## Base Image Selection Guide (Best Practice #6)

| Priority | Base Image | Use Case |
|----------|------------|----------|
| Security-critical | `gcr.io/distroless/python3` | No shell, no package manager, minimal attack surface |
| Size-optimized | `python:3.12-alpine` | Small image, musl libc (check compatibility) |
| Compatibility | `python:3.12-slim` | Debian slim, glibc, broader package availability |
| Never | `python:3.12` (full) | Includes build tools, 800MB+ — build stage only |
| Never | `python:latest` | Non-reproducible, breaks on new Python release |

Distroless caveats: no shell for debugging, no `apt-get`. Use a debug variant
(`gcr.io/distroless/python3:debug`) in non-production for shell access.

Alpine caveats: musl libc can cause issues with some compiled Python packages
(numpy, cryptography). Test thoroughly before committing to Alpine.

Always pin to a minor version: `python:3.12-slim`, `node:22-alpine`. Use
digest pinning for supply-chain-sensitive workloads:
```dockerfile
FROM python:3.12-slim@sha256:abc123...
```

## apt-get Patterns (Best Practice #8)

Always chain `update` and `install` in a single `RUN` layer:

```dockerfile
# Correct: single layer, clean up cache
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Wrong: split layers cause stale cache bug
RUN apt-get update
RUN apt-get install -y libpq-dev  # may use cached (stale) package lists
```

With BuildKit cache mounts (preferred for faster builds):
```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev curl
# No need for rm -rf when using cache mounts — lists stay in cache, not layer
```

`--no-install-recommends` significantly reduces installed package count.
Always include it for production images.

## Compose Secrets (Best Practice #9)

```yaml
services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    environment:
      # Reference path, not the value
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt   # local dev
  api_key:
    environment: API_KEY_SECRET       # from environment variable
```

In production (Docker Swarm or Kubernetes), secrets are injected via the
orchestrator rather than files. The app reads from `/run/secrets/<name>` —
update app code to support `_FILE` suffix pattern for 12-factor compatibility.

Never use `environment:` for passwords — they appear in `docker inspect`,
`docker-compose config`, and process environment listings.

## Compose Profiles (Best Practice #10)

```yaml
services:
  app:
    image: myapp:latest
    # No profile = always started

  pgadmin:
    image: dpage/pgadmin4
    profiles: [debug]
    depends_on:
      - db

  prometheus:
    image: prom/prometheus
    profiles: [monitoring]

  grafana:
    image: grafana/grafana
    profiles: [monitoring]
```

Start with profiles:
```bash
docker compose --profile debug up        # app + pgadmin
docker compose --profile monitoring up   # app + prometheus + grafana
docker compose --profile debug --profile monitoring up  # everything
```

Use profiles for: local dev tools (pgadmin, mailhog), observability stack
(prometheus, grafana, jaeger), load testing tools (k6, locust).

## Image Scanning (Best Practice #11)

Trivy in CI:
```bash
# Block on CRITICAL or HIGH severity
trivy image --exit-code 1 --severity CRITICAL,HIGH myapp:$TAG

# Generate SBOM
trivy image --format cyclonedx --output sbom.json myapp:$TAG
```

Docker Scout:
```bash
docker scout cves myapp:$TAG --exit-code --only-severity critical,high
```

Integrate in GitHub Actions:
```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:${{ github.sha }}
    exit-code: '1'
    severity: 'CRITICAL,HIGH'
```

Never push an unscanned image to a production registry. Block merges on new
CRITICAL findings. Schedule weekly rescans of production image tags for
vulnerability disclosure after initial push.

## Read-Only Filesystem (Best Practice #12)

Docker run:
```bash
docker run --read-only --tmpfs /tmp --tmpfs /var/run myapp:latest
```

Docker Compose:
```yaml
services:
  app:
    image: myapp:latest
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
    volumes:
      - app-data:/data  # named volume for persistent writable data
```

Common directories needing tmpfs: `/tmp`, `/var/run`, `/var/cache`,
application-specific temp dirs. Identify by running without `--read-only`
first and monitoring write failures.

Read-only root filesystem prevents: persistence of malware, config tampering,
accidental log writes to container layer. Combine with `--cap-drop ALL` and
`--security-opt no-new-privileges` for defense in depth.

## Troubleshooting Details

### Error: Docker layer cache invalidated on every build

Cause: Source code copied before dependency manifests, so any code change
invalidates the dependency install layer.

Solution — correct layer order:
```dockerfile
# 1. Copy only manifests first
COPY requirements.txt pyproject.toml ./
# 2. Install deps (cached unless manifests change)
RUN pip install -r requirements.txt
# 3. Copy source last (invalidates only code layer)
COPY src/ ./src/
```

Full order: `FROM` → system packages → language runtime config → dependency
manifests → dependency install → application source.

### Error: Container runs as root despite USER directive in Dockerfile

Cause: `USER` placed before `RUN` or `COPY` commands that require root in
a subsequent stage, or a multi-stage build doesn't re-set the user in the
final stage.

Solution:
```dockerfile
# In final stage: do all root operations first, then switch
RUN groupadd -r app && useradd -r -g app app
COPY --chown=app:app src/ ./src/
USER app   # switch last, before CMD/ENTRYPOINT
```

Verify: `docker run --rm myapp whoami` should return `app`, not `root`.
Also check with `docker inspect --format='{{.Config.User}}' myapp`.

### Error: Compose service starts before dependency is actually ready

Cause: Basic `depends_on` waits only for container start signal, not for the
service inside to be accepting connections.

Solution:
```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s   # don't count failures during startup

  app:
    depends_on:
      db:
        condition: service_healthy  # waits for green healthcheck
```

Also add application-level retry logic (exponential backoff on DB connection)
as defense in depth — orchestrators like Kubernetes don't guarantee `depends_on`
semantics.
