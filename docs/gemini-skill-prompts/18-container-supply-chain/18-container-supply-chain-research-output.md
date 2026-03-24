Of course. This is an excellent use case for Gemini. A comprehensive, structured knowledge base is precisely what AI agents need to perform effectively. I will generate a detailed research document covering the entire container supply chain, structured for your AI agents' consumption.

Here is the deep research on your container supply chain, from Dockerfile authoring to runtime enforcement.

# Dockerfile & BuildKit Best Practices

## ## SKILL.md Content

```markdown
# Dockerfile & BuildKit Quick Reference

### Core Concepts

- **Multi-stage Builds**: Use `FROM ... AS builder` to compile/build, then `FROM <distroless/alpine>` to create a minimal final image. Only `COPY --from=builder` the necessary artifacts (binaries, static assets).
- **Base Image**: Prefer `cgr.dev/chainguard/static` or `gcr.io/distroless/static-debian12` for Go/Rust. <!-- Pin by digest in production: @sha256:... See reference.md for pinning guide --> Use `cgr.dev/chainguard/python` or `cgr.dev/chainguard/nodejs` for interpreted languages. Use Alpine as a fallback if specific packages are needed. Avoid `ubuntu` or full OS images.
- **Layer Caching**: Order commands from least to most frequently changing.
  1. `FROM ...@sha256:...` (Pin base image digest)
  2. `WORKDIR /app`
  3. `COPY package.json ./`
  4. `RUN --mount=type=cache,target=/root/.npm npm ci` (Use cache mount for package managers)
  5. `COPY . .` (Copy source code last)
  6. `RUN npm run build`
- **Security**:
  - Run as non-root: `USER 1001:1001` or `USER nonroot` (for Chainguard images).
  - Use `COPY --chown=1001:1001` to set ownership without an extra `RUN` layer.
- **Reproducibility**:
  - Always pin base image with a digest: `FROM alpine:3.18@sha256:....`
  - Use deterministic package installs (`npm ci`, `pip install -r requirements.txt`).
- **BuildKit Usage**: Always use BuildKit. Set `DOCKER_BUILDKIT=1` in your CI environment.

### Common Commands & Snippets

**Minimal Go Multi-stage Dockerfile:**
```dockerfile
# ---- Builder Stage ----
FROM golang:1.21-alpine AS builder

WORKDIR /src

# Use cache mount for Go modules
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /app .

# ---- Final Stage ----
FROM gcr.io/distroless/static-debian12

WORKDIR /
COPY --from=builder /app /app
USER 65532:65532

ENTRYPOINT ["/app"]
```

**Minimal Node.js Multi-stage Dockerfile:**
```dockerfile
# ---- Builder Stage ----
FROM cgr.dev/chainguard/node:20 AS builder
WORKDIR /app
USER nonroot

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/home/nonroot/.npm \
    npm ci

COPY . .
RUN npm run build

# ---- Final Stage ----
FROM cgr.dev/chainguard/node:20-runtime
WORKDIR /app
USER nonroot

# Copy only production dependencies and built assets
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

**Essential `.dockerignore`:**
```
.git
.gitignore
.dockerignore
node_modules
npm-debug.log
Dockerfile
README.md
*.secret
*.env
# Local development files
.vscode/
# Test fixtures
test/
```

**BuildKit Secret Mount:**
```dockerfile
# Example: Accessing a secret to pull a private package
# In CI: docker build --secret id=npmrc,src=.npmrc .
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

### Troubleshooting

- **Symptom**: Builds are slow.
  - **Cause**: Poor layer caching. Source code `COPY` is happening before package manager `RUN`.
  - **Fix**: Reorder Dockerfile instructions. `COPY` dependency manifest, `RUN` package install, then `COPY` the rest of the code. Use `RUN --mount=type=cache`.
- **Symptom**: Image size is huge (>1GB).
  - **Cause**: Not using multi-stage builds. Including build tools (GCC, Node.js, Go toolchain) in the final image.
  - **Fix**: Implement a multi-stage build. Use a `builder` stage, and `COPY` only the compiled binary or built assets into a minimal final stage (distroless/chainguard).
- **Symptom**: `docker history` shows secret values.
  - **Cause**: Using `ARG` or `ENV` to pass secrets.
  - **Fix**: Use BuildKit secret mounts (`--secret` and `RUN --mount=type=secret`). Secrets are never committed to layers.
```

## ## reference.md Content

```markdown
# OCI Image Build: Deep Reference

### Dockerfile Best Practices

#### Multi-stage Builds
- **Anatomy**: A Dockerfile with multiple `FROM` instructions. Each `FROM` starts a new, independent build stage. Stages can be named with `AS <name>`.
- **Purpose**: To separate the build environment from the runtime environment. This dramatically reduces the size of the final image and its attack surface by excluding compilers, SDKs, dev dependencies, and source code.
- **Mechanism**: The `COPY --from=<stage_name_or_index>` instruction copies files from a previous stage into the current one.
- **Files NOT to Copy**:
  - Source code (`.go`, `.js`, `.py`) unless it's an interpreted language.
  - Build manifests (`package.json`, `go.mod`). Copy only compiled artifacts.
  - Intermediate build artifacts (`.o` files).
  - Testing libraries and fixtures.

#### Base Image Selection
| Base Image Type | Pros | Cons | Best For |
|---|---|---|---|
| **Chainguard (`cgr.dev`)** | Ultra-minimal, zero known CVEs, signed by default, non-root user. | Very few packages available, `apk` is not present by default. | **Default choice for Helix Stax.** Go, Rust, Node.js, Python. Maximum security. |
| **Distroless (`gcr.io`)** | Very small, no shell, no package manager. Minimal attack surface. | Debugging is difficult (no shell). Fewer language-specific variants than Chainguard. | Go, Rust, Java, or other statically compiled languages. When Chainguard is not an option. |
| **Alpine (`alpine`)** | Small, fast, has `apk` package manager. | Uses `musl libc`, which can have subtle incompatibilities. | When you need specific Linux packages not available in Distroless/Chainguard. |
| **UBI 9 (`redhat/ubi9`)** | Red Hat supported, `glibc`-based, stable ABI/API. `dnf` package manager. | Larger than Alpine/Distroless. Enterprise-focused. | Workloads requiring RHEL compatibility or specific `glibc` features. Good fit for AlmaLinux host OS. |

#### Layer Caching Strategy
The Docker/Kaniko builder caches the result of each instruction. If an instruction's inputs haven't changed, the cached layer is reused.
- **Invalidation**: A change in a layer invalidates all subsequent layers.
- **Optimal Order**:
  1. `FROM` (Digest pinning prevents accidental base image updates from invalidating cache).
  2. `ENV`, `LABEL`, `WORKDIR` (Change infrequently).
  3. `COPY` package manager manifests (`package.json`, `requirements.txt`, `go.mod`).
  4. `RUN` package installation, using a cache mount (`RUN --mount=type=cache...`). This keeps the package cache separate from the image layer, preventing cache invalidation on code changes.
  5. `COPY . .` (Copy the rest of the source code. This changes most frequently and should be last).
  6. `RUN` build/compile steps.
  7. `CMD`/`ENTRYPOINT`.

#### `.dockerignore`
- **Purpose**: Prevents files from being sent to the build context, reducing build time, avoiding accidental secret leakage, and preventing unnecessary cache invalidation.
- **Syntax**: Uses `gitignore` style glob patterns. `!` prefix negates a pattern.
- **Always Exclude**: `.git`, `node_modules`, `venv`, build output directories (`dist`, `target`), secrets (`.env`, `*.pem`), IDE configs (`.vscode`, `.idea`), temporary files (`*~`).

#### User and Permissions
- **Principle of Least Privilege**: Never run containers as `root`. Root in a container can often map to root on the host, especially without user namespacing.
- **`USER` Instruction**: Use a high, non-zero UID. `USER 1001:1001` is a common convention. Kubernetes uses this for `runAsUser`.
- **`--chown` flag**: Use `COPY --chown=<user>:<group>` to set file ownership during the copy, avoiding an extra `RUN chown ...` layer.
- **Numeric UIDs**: Always use numeric UIDs/GIDs (`1001:1001`) instead of names (`appuser:appgroup`). Names may not exist in minimal base images or may resolve to different UIDs, causing issues in Kubernetes `SecurityContext`.

#### `COPY` vs `ADD`
- **`COPY`**: Preferred for its transparency. It copies local files and directories into the image.
- **`ADD`**: Has "magic" features that reduce reproducibility.
  - It can fetch remote URLs (can fail, resources can change).
  - It automatically extracts local tarballs (`.tar.gz`, etc.). This is often unexpected.
- **Rule of Thumb**: Always use `COPY` unless you explicitly need `ADD`'s tar auto-extraction feature.

#### `ARG` vs `ENV`
| Instruction | Scope | Purpose | Security Warning |
|---|---|---|---|
| **`ARG`** | Build-time only. Not available in the running container. | Pass variables from the `build` command into the `Dockerfile`. | **Do NOT use for secrets.** `ARG` values are visible in `docker history` and image metadata. |
| **`ENV`** | Build-time AND Runtime. Persists in the final image. | Set environment variables for the running container. | Value is baked into the image layer, visible to anyone with access to the image. Not for secrets. |

#### `HEALTHCHECK`
- **Syntax**: `HEALTHCHECK [OPTIONS] CMD <command>`
- **Purpose**: Provides a container-native way to report application health.
- **Exit Codes**: `0` = healthy, `1` = unhealthy, `2` = reserved.
- **Kubernetes Interaction**: `HEALTHCHECK` is independent of K8s probes but can be a signal. K8s `livenessProbe` and `readinessProbe` are more powerful and control pod lifecycle directly. It's often better to rely on K8s probes and omit `HEALTHCHECK` unless running the image on a non-K8s platform.

#### Labels and Annotations (OCI Spec)
- **Purpose**: Store metadata directly on the image manifest.
- **Standard Annotations**:
  - `org.opencontainers.image.created`: Build timestamp (RFC 3339).
  - `org.opencontainers.image.source`: Git source repository URL.
  - `org.opencontainers.image.version`: Git commit SHA.
  - `org.opencontainers.image.revision`: Git commit SHA.
  - `org.opencontainers.image.licenses`: License (e.g., "Apache-2.0").
  - `org.opencontainers.image.description`: Human-readable description.
- **Usage**: `LABEL org.opencontainers.image.source="https://github.com/helix-stax/my-app"`
- **Harbor**: These labels/annotations are displayed in the Harbor UI under the artifact's "Info" tab.

#### Reproducible Builds
- **Goal**: The same source code (commit SHA) should always produce a bit-for-bit identical image.
- **Techniques**:
  1. **Pin Base Image Digest**: `FROM alpine@sha256:21a3deaa0d32a8057914f365844cd79828e5218009247ae0929be85652a0D4F3`
  2. **Deterministic Installs**: Use lockfiles (`package-lock.json`, `go.sum`, `Pipfile.lock`).
  3. **Fix Timestamps**: `SOURCE_DATE_EPOCH` environment variable. Many build tools will use this to set timestamps in compiled artifacts, preventing changes on every build. `export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)`
  4. **Stable Build Environment**: Use the same builder image version.

### BuildKit Features

- **Enabling**: `export DOCKER_BUILDKIT=1`
- **Architecture**: A client/daemon model (`buildctl` -> `buildkitd`). The daemon provides advanced features like concurrent builds, efficient pruning, and advanced mounts.

#### Mounts (`RUN --mount=...`)
- **`--secret`**: Mounts a secret file into the `RUN` command at `/run/secrets/<id>`. The secret is not part of the build context or final image layers.
  - **Syntax**: `docker build --secret id=mysecret,src=./secret.txt .`
  - **Dockerfile**: `RUN --mount=type=secret,id=mysecret cat /run/secrets/mysecret`
- **`--ssh`**: Forwards the host's SSH agent socket into the build. Useful for cloning private Git repositories during build.
  - **Syntax**: `docker build --ssh default .`
  - **Dockerfile**: `RUN --mount=type=ssh git clone git@github.com:my-private-org/repo.git`
- **`--cache`**: Mounts a persistent cache directory. Invaluable for package managers.
  - **Syntax**: `RUN --mount=type=cache,target=/root/.npm npm ci`
  - **Benefit**: The `/root/.npm` directory persists across builds, even if `package.json` changes. Only new packages are downloaded.

#### Caching
- **`--cache-from`**: Tells BuildKit to pull layers from a remote registry to prime the local build cache.
- **`--cache-to`**: Tells BuildKit where to push the resulting build cache.
- **`type=inline`**: Embeds cache metadata directly into the image being built and pushed. This is the simplest method but bloats the image manifest.
- **`type=registry`**: Pushes cache layers to a separate manifest in a registry. This is the recommended approach for Kaniko and CI/CD.
  - **Syntax**: `... --cache-from=type=registry,ref=harbor.helixstax.net/kaniko-cache/myapp --cache-to=type=registry,ref=harbor.helixstax.net/kaniko-cache/myapp,mode=max`

#### `bake` Files
- **Purpose**: Define multiple build targets in a single HCL or JSON file, allowing for complex, matrix, and parallel builds.
- **Example (`docker-bake.hcl`)**:
  ```hcl
  target "default" {
    tags = ["harbor.helixstax.net/dev/myapp:latest"]
  }

  target "prod" {
    tags = ["harbor.helixstax.net/prod/myapp:v1.2.3"]
    dockerfile = "Dockerfile.prod"
    platforms = ["linux/amd64", "linux/arm64"]
  }
  ```
- **Execution**: `docker bake prod`
```

## ## examples.md Content

```markdown
# Dockerfile & BuildKit: Helix Stax Examples

### Example 1: Production-Ready Go Service Dockerfile

This is the standard Dockerfile for a Go-based microservice at Helix Stax.

**`Dockerfile`**
```dockerfile
# =========================================================================
# ---- Builder Stage: Compile the Go application into a static binary ----
# =========================================================================
# Use a specific version of the golang image for reproducibility.
# The alpine variant is small and contains the necessary build tools.
ARG GOLANG_VERSION=1.21
FROM golang:${GOLANG_VERSION}-alpine AS builder

# Set the working directory inside the container.
WORKDIR /src

# Security: Create a non-root user/group to own files. We'll use this
# throughout the build and in the final image. UID/GID 1001 is a common
# default for non-system users.
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup
USER appuser

# Use BuildKit cache mount for Go modules. This command downloads dependencies.
# The cache is persisted across builds, speeding up subsequent builds significantly.
# Copy mod/sum files first to leverage layer caching.
COPY --chown=appuser:appgroup go.mod go.sum ./
RUN --mount=type=cache,target=/home/appuser/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy the rest of the source code. This is done after dependency download
# so that code changes don't invalidate the dependency layer.
COPY --chown=appuser:appgroup . .

# Build the application. CGO_ENABLED=0 creates a static binary.
# '-ldflags="-s -w"' strips debug symbols to reduce size.
# The output is a single file named 'app' in the root directory.
ARG GIT_SHA="unknown"
ARG BUILD_DATE="unknown"
RUN --mount=type=cache,target=/home/appuser/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.Version=${GIT_SHA} -X main.BuildDate=${BUILD_DATE}" \
    -a -installsuffix cgo -o /app .

# =========================================================================
# ---- Final Stage: Create the minimal production image ----
# =========================================================================
# Use a distroless static image. It contains only our binary, its dependencies,
# and some essential files like CA certificates. No shell, no package manager.
# Pinning the digest is a critical security and reproducibility practice.
FROM gcr.io/distroless/static-debian12@sha256:3c393798c8087342085311910b42b99292854afe2a10d9f7823f9f743c3ff142

# Define OCI image annotations for provenance and discovery in Harbor.
LABEL org.opencontainers.image.source="https://github.com/helix-stax/example-service"
LABEL org.opencontainers.image.description="Example Go microservice for Helix Stax."
LABEL org.opencontainers.image.licenses="Apache-2.0"

WORKDIR /
# Copy the compiled binary from the 'builder' stage.
COPY --from=builder /app .
# Copy the non-root user from the builder stage. This is a distroless feature.
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Run as the non-root user. UID 1001 must match the user created above.
USER 1001

# Run the binary when the container starts.
ENTRYPOINT ["/app"]
```

### Example 2: Helix Stax `.dockerignore`

This file should be placed in the root of every service repository.

**`.dockerignore`**
```
# Git specific files
.git
.gitignore
.gitattributes

# Docker specific files
.dockerignore
Dockerfile
docker-compose.yml

# Build artifacts
/dist
/build
/target
/bin

# Dependency directories
node_modules
vendor/
venv/

# Log and temp files
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
tmp/

# Secret files
*.env
*.pem
*.key
*.secret
credentials.json
.npmrc

# IDE and OS files
.vscode/
.idea/
*.swp
*~
.DS_Store
```

### Example 3: `bake` file for Multi-environment Builds

This file, `docker-bake.hcl`, defines how to build images for `dev` and `prod`.

**`docker-bake.hcl`**
```hcl
# Common variables used across targets
variable "GIT_SHA" {
  default = "dev"
}
variable "BUILD_DATE" {
  default = ""
}

# Group defines common settings for all targets in the group
group "default" {
  targets = ["dev", "prod-amd64", "prod-arm64"]
}

# Target for development builds
target "dev" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["harbor.helixstax.net/dev/example-service:sha-${GIT_SHA}"]
  args = {
    GIT_SHA    = GIT_SHA
    BUILD_DATE = BUILD_DATE
  }
  # Use an external registry for caching
  cache-from = ["type=registry,ref=harbor.helixstax.net/kaniko-cache/example-service"]
  cache-to   = ["type=registry,ref=harbor.helixstax.net/kaniko-cache/example-service,mode=max"]
}

# Target for AMD64 production build
target "prod-amd64" {
  inherits   = ["dev"] # Inherits settings from dev
  platforms  = ["linux/amd64"]
  tags       = ["harbor.helixstax.net/staging/example-service:1.0.0-amd64"]
}

# Target for ARM64 production build
target "prod-arm64" {
  inherits   = ["dev"]
  platforms  = ["linux/arm64"]
  tags       = ["harbor.helixstax.net/staging/example-service:1.0.0-arm64"]
}
```

**Usage in CI:**
```bash
# Get Git SHA and build date
export GIT_SHA=$(git rev-parse --short HEAD)
export BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Build the dev image
docker buildx bake dev

# Build both prod images in parallel
docker buildx bake prod-amd64 prod-arm64

# Create and push a multi-arch manifest list to staging
docker buildx imagetools create -t harbor.helixstax.net/staging/example-service:1.0.0 \
  harbor.helixstax.net/staging/example-service:1.0.0-amd64 \
  harbor.helixstax.net/staging/example-service:1.0.0-arm64
```
```
---

# Kaniko

## ## SKILL.md Content

```markdown
# Kaniko Quick Reference

### Core Concepts
- **What it is**: A tool to build container images from a Dockerfile, inside a container or Kubernetes pod, without needing a Docker daemon.
- **How it works**:
  1. Fetches a base image file system.
  2. Executes Dockerfile commands one by one.
  3. Takes a file system snapshot after each command.
  4. Appends a new layer (the diff from the previous snapshot) to the image.
  5. Pushes the final image directly to a remote registry.
- **Key Use Case**: Securely building images in Kubernetes CI/CD pipelines (like Devtron) without exposing the Docker socket.

### Basic Usage in a Kubernetes Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-build-pod
spec:
  containers:
  - name: kaniko
    # Use a pinned digest for reproducibility
    image: gcr.io/kaniko-project/executor:v1.12.1-debug@sha256:d8745e76a6a9be7520d65451c8907b81f335520a233486105e1b6f0e3408a2b5
    args:
      - "--context=git://github.com/helix-stax/example-service.git#refs/heads/main"
      - "--dockerfile=Dockerfile"
      - "--destination=harbor.helixstax.net/dev/example-service:latest"
      # Enable caching to a dedicated Harbor repo
      - "--cache=true"
      - "--cache-repo=harbor.helixstax.net/kaniko-cache/example-service"
      - "--cache-ttl=24h"
    volumeMounts:
      - name: docker-config
        mountPath: /kaniko/.docker/
        readOnly: true
  restartPolicy: Never
  volumes:
    - name: docker-config
      secret:
        secretName: harbor-registry-secret
        items:
          - key: .dockerconfigjson
            path: config.json
```

### Essential Flags

- `--context`: Build context location.
  - `git://...`: Git repository.
  - `dir:///workspace/`: Local directory inside the pod.
- `--dockerfile`: Path to Dockerfile within the context. Default: `Dockerfile`.
- `--destination`: Image destination, including tag. Kaniko will push here.
- `--cache=true`: Enable layer caching.
- `--cache-repo`: The registry repository to store cache layers. (e.g., `harbor.helixstax.net/kaniko-cache/my-app`). Essential for performance.
- `--target`: Build a specific stage from a multi-stage Dockerfile.
- `--build-arg`: Pass arguments to the build (`KEY=VALUE`).

### Troubleshooting

- **Symptom**: `error resolving dockerfile path`, `error building image`, `context needs to be a directory`.
  - **Cause**: `--context` path is wrong, or `--dockerfile` is not found within the context.
  - **Fix**: Verify the git URL and branch (`#refs/heads/<branch>`). For local context (`dir://`), ensure your CI tool has cloned the repo into that directory. Check file paths.
- **Symptom**: `error pushing image: unauthorized: authentication required`.
  - **Cause**: Kaniko cannot authenticate with `harbor.helixstax.net`.
  - **Fix**:
    1. Ensure the Kubernetes secret (`harbor-registry-secret`) exists and contains valid `config.json` data for a robot account.
    2. Verify the `volumeMount` is correctly mounting the secret to `/kaniko/.docker/config.json`.
    3. Check robot account permissions in Harbor. It needs `push` access to the destination and cache repos.
- **Symptom**: `Permission denied` when writing to `/workspace` or other directories.
  - **Cause**: The Kaniko container runs as non-root (good!) but the underlying pod security context or CI volume permissions are too restrictive.
  - **Fix**: In your Pod spec or Devtron CI definition, set a `securityContext` that allows writing to the workspace volume:
    ```yaml
    securityContext:
      runAsUser: 1000
      fsGroup: 1000
    ```
- **Symptom**: Build fails on `RUN --mount=type=secret`.
  - **Cause**: Kaniko has limited support for BuildKit features. As of v1.12, secret mounts are not fully supported in the same way.
  - **Fix**: Use an alternative method. Mount Kubernetes secrets as files into the Kaniko pod and `COPY` them, then use a multi-stage build to ensure they are not in the final image. Or, use a tool that can inject secrets at runtime.
```

## ## reference.md Content

```markdown
# Kaniko: Deep Reference

### How Kaniko Works

Kaniko operates entirely in userspace, which is its primary security advantage.

1.  **Executor Image**: The `gcr.io/kaniko-project/executor` image contains the Go binary that is the Kaniko build engine.
2.  **Filesystem Extraction**: It fetches the base image specified in the `FROM` instruction and extracts its filesystem into the pod's `/kaniko` directory.
3.  **Command Execution**: For each Dockerfile command (`RUN`, `COPY`, `ADD`):
    *   It executes the command.
    *   After execution, it takes a snapshot of the entire filesystem in userspace.
    *   It compares the new snapshot with the previous one to create a tarball (`.tar.gz`) of the diff. This tarball is a new image layer.
4.  **Metadata Updates**: It updates the image's config JSON with changes from instructions like `ENV`, `USER`, `WORKDIR`.
5.  **Registry Push**: After the last command, Kaniko bundles all the generated layers and the config JSON into a manifest and pushes everything directly to the destination registry. It does not interact with a local daemon like containerd or dockerd.

**(ASCII Diagram)**
```
+---------------------------+       +------------------------------------+
|   Devtron CI K8s Pod      |       |  Harbor Registry                   |
| +-----------------------+ |       |  (harbor.helixstax.net)          |
| |   Kaniko Container    | |       +------------------------------------+
| | +-------------------+ | | Reads   |   +---------------------------+    |
| | | Executor Binary   | |<--------+   |  Base Image Layers        |    |
| | +-------------------+ | |       |   +---------------------------+    |
| |                       | |       |                                    |
| | /kaniko (workspace)   | | Pushes  |   +---------------------------+    |
| |  - fs snapshot A      | +-------> |   |  New Layers (from diff)   |    |
| |  - fs snapshot B      | |         |   +---------------------------+    |
| |                       | |       |                                    |
| | /kaniko/.docker/cfg.json| | Pushes  |   +---------------------------+    |
| +-----------------------+ | +-------> |   |  Image Manifest & Config  |    |
+---------------------------+           +---------------------------+    |
      (No Docker Daemon)                    (Final Artifact)
```

### Full Flag Reference (Selected)

| Flag | Description | Default |
|---|---|---|
| `--context` | **Required.** Path to the build context. `dir://`, `git://`, `s3://` | |
| `--destination` | **Required.** Registry reference to push the image to. Multiple destinations allowed. | |
| `--dockerfile` | Path to the Dockerfile in the context. | `Dockerfile` |
| `--cache` | Enable layer caching. Recommended: `true`. | `false` |
| `--cache-repo` | Remote repository to store cache layers. **Crucial for performance.** | |
| `--cache-ttl` | Cache timeout. | `1440h` (60 days) |
| `--cache-copy-layers` | If `true`, copies layers from the base image to the cache. | `false` |
| `--snapshotMode` | `full` (snapshot full FS), `redo` (re-executes commands to get diff), `time` (snapshot based on mtime). `time` is faster but less reproducible. **`redo` is recommended.** | `full` |
| `--verbosity` | Log level: `panic`, `fatal`, `error`, `warn`, `info`, `debug`, `trace`. | `info` |
| `--target` | Build a specific stage in a multi-stage Dockerfile. | (builds last stage) |
| `--skip-unused-stages` | If `true`, does not execute commands in stages not required for the final `--target`. | `false` |
| `--insecure` | Allow HTTP to registry. **Avoid.** Use TLS. | `false` |
| `--insecure-pull` | Allow HTTP for pulling base image. **Avoid.** | `false` |
| `--insecure-skip-tls-verify` | Skip TLS certificate verification. **Avoid.** Use a proper CA. | `false` |
| `--build-arg` | Pass build-time argument. (`key=value`) | |
| `--label` | Add OCI label to the image. (`key=value`) | |

### BuildKit Parity and Gaps

Kaniko aims for Dockerfile compatibility but does not use BuildKit internally. Its support for advanced BuildKit features is partial and re-implemented.

| BuildKit Feature | Kaniko Support | Notes |
|---|---|---|
| Multi-stage Builds | **Yes** | Fully supported and a core feature. |
| `RUN --mount=type=cache` | **Yes (Partial)** | Works well for package managers. May have edge cases. |
| `RUN --mount=type=secret` | **No (Effectively)** | Not implemented. Kaniko recommends mounting K8s secrets as files instead. |
| `RUN --mount=type=ssh` | **No** | Not implemented. Use a git credential helper or access token in the git URL. |
| `RUN --mount=type=bind` | **No** | |
| `bake` files | **No** | Kaniko builds one image at a time. Orchestrate matrix builds in your CI tool (e.g., Devtron). |
| External Cache (`--cache-to`) | **Yes** | This is Kaniko's core caching mechanism via `--cache-repo`. |

### Devtron CI Integration
In Devtron, the CI pipeline is a Kubernetes Pod. You define a 'Build' step and select `kaniko` as the tool.

- **Dockerfile location**: Devtron checks out the git repo, so the path is relative to the repo root.
- **Destination Image**: Devtron automatically constructs the `--destination` flag based on your pipeline configuration (Docker registry, image name, and tag generation logic like `sha-$GIT_SHA`).
- **Credentials**: Devtron automatically uses the configured Docker Registry secret and mounts it for Kaniko.

**Devtron Pipeline YAML Snippet:**
```yaml
# This is a conceptual representation of Devtron's configuration
...
steps:
  - name: build-with-kaniko
    plugin:
      image: gcr.io/kaniko-project/executor:v1.12.1-debug
      args:
        # Devtron injects these values from the UI configuration
        # --context: git://...
        # --destination: harbor.helixstax.net/dev/myapp:sha-abc1234
        # Other hardcoded flags can be added here
        - "--cache=true"
        - "--cache-repo=harbor.helixstax.net/kaniko-cache/myapp"
        - "--cache-ttl=48h"
        - "--verbosity=info"
        - "--snapshotMode=redo"
```

### Common Failures Deep Dive
- **Registry Auth Errors**: Usually caused by an incorrect `config.json`. The file content should be a base64 encoded string of `robot_user:robot_token`. Ensure the robot account has `push` and `pull` (for cache) permissions on the target project(s) in Harbor.
- **Context Size Limits**: While Kaniko doesn't have a hard limit like the Docker daemon, a huge context (e.g., a git repo with large binary files not in `.dockerignore`) can slow down the initial checkout and processing, potentially hitting pod resource limits or timeouts.
- **Insecurity Flags (`--insecure*`)**: **Never use these for `harbor.helixstax.net`**. Your K3s cluster & Harbor setup should use proper TLS, managed by Traefik and cert-manager. These flags are a security anti-pattern and only acceptable for legacy, air-gapped systems, which is not your use case. If Kaniko doesn't trust the registry's certificate, it's a sign that the CA certificate is missing, not that you should disable TLS.
- **`--skip-unused-stages`**: This is a valuable optimization. For a multi-stage Dockerfile where you are building a specific `--target`, setting this flag prevents Kaniko from wastefully executing stages that aren't a dependency of your target stage.
```

## ## examples.md Content

```markdown
# Kaniko: Helix Stax Examples

### Example 1: Devtron CI Build Step Configuration

This is what a configured 'Build' step in the Devtron UI for a service named `user-api` would look like conceptually, translated to the underlying pod configuration.

**Assumptions:**
- Your Devtron environment is configured with access to the `harbor.helixstax.net` Harbor instance.
- A robot account `devtron-builder` exists in Harbor with push/pull access to `dev/user-api` and `kaniko-cache/user-api`.

**Effective Kaniko Pod Spec generated by Devtron:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ci-user-api-build-123
  namespace: devtron-ci
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:v1.12.1-debug@sha256:d8745e76a6a9be7520d65451c8907b81f335520a233486105e1b6f0e3408a2b5
    # Devtron dynamically populates these arguments based on pipeline config
    args:
      # Context is the checked out git repo
      - "--context=git://github.com/helix-stax/user-api.git#refs/heads/feature/new-login"
      # Dockerfile path within the repo
      - "--dockerfile=Dockerfile"
      # Destination constructed from registry URL, app name, and Git SHA
      - "--destination=harbor.helixstax.net/dev/user-api:sha-a8b3c1d"
      # Enable caching using a dedicated Harbor project
      - "--cache=true"
      - "--cache-repo=harbor.helixstax.net/kaniko-cache/user-api"
      - "--cache-ttl=48h" # Cache valid for 2 days
      # Use a reproducible snapshotting mode
      - "--snapshotMode=redo"
      # Build a specific stage if needed, e.g., for testing
      - "--target=final"
      # OCI annotations passed as build-args and applied with LABEL
      - "--label=org.opencontainers.image.source=https://github.com/helix-stax/user-api"
      - "--label=org.opencontainers.image.revision=a8b3c1d9e2f0"
    # Devtron mounts the registry credentials secret
    volumeMounts:
      - name: docker-config
        mountPath: /kaniko/.docker/
        readOnly: true
  restartPolicy: Never
  volumes:
    - name: docker-config
      secret:
        # Secret name is configured in Devtron's "Container Registries" settings
        secretName: harbor-helixstax-net-secret
        items:
          - key: .dockerconfigjson
            path: config.json
```

### Example 2: Creating the Harbor Registry Secret (`config.json`)

This Kubernetes secret provides Kaniko with the credentials to push to `harbor.helixstax.net`.

1.  **Get Harbor Robot Account Credentials:**
    - In Harbor, go to Project `dev` -> Robot Accounts -> New Robot Account.
    - Name: `devtron-user-api`
    - Permissions: `push` and `pull` for repository `user-api`. Add `push` and `pull` for `kaniko-cache/user-api` as well.
    - Harbor will provide a token. E.g., `robot$dev-devtron-user-api:SOME_LONG_TOKEN`.

2.  **Create the `config.json` file locally:**

    **`config.json`**
    ```json
    {
      "auths": {
        "harbor.helixstax.net": {
          "auth": "cm9ib3QkZGV2LWRldnRyb24tdXNlci1hcGk6U09NRV9MT05HX1RPS0VO"
        }
      }
    }
    ```
    - The `auth` value is the base64 encoding of `username:password`.
    - In bash: `echo -n 'robot$dev-devtron-user-api:SOME_LONG_TOKEN' | base64`

3.  **Create the Kubernetes Secret:**
    ```bash
    kubectl create secret generic harbor-registry-secret \
      --from-file=.dockerconfigjson=./config.json \
      --type=kubernetes.io/dockerconfigjson \
      -n devtron-ci # Create it in the namespace where CI pods run
    ```
    *Note: Devtron typically manages this secret creation for you when you add a registry in its UI.*

### Example 3: Debugging a Kaniko Failure in Devtron

**Scenario**: A build fails with an authentication error in the Devtron logs.

**Log Output:**
```
...
INFO[0030] Pushing image to harbor.helixstax.net/dev/user-api:sha-a8b3c1d
error pushing image: failed to push to destination harbor.helixstax.net/dev/user-api:sha-a8b3c1d: UNAUTHORIZED: authentication required
```

**Debugging Steps:**

1.  **Check Robot Account**: Go to Harbor UI. Does the robot account `devtron-user-api` exist? Is it enabled?
2.  **Check Permissions**: Click on the robot account. Does it have `push` permission for the `dev/user-api` repository?
3.  **Inspect the Secret in K8s**:
    ```bash
    # Get the secret used by the CI pod in the devtron-ci namespace
    kubectl get secret harbor-registry-secret -n devtron-ci -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode
    ```
    This command will print the `config.json` content.
4.  **Verify the `auth` field**:
    ```bash
    # The output from the previous command is a JSON string. Copy the "auth" value.
    echo "PASTE_THE_AUTH_VALUE_HERE" | base64 --decode
    ```
    The output should be `robot$user:token`. Does it match the token from Harbor? If not, the secret is stale or was created incorrectly.
5.  **Fix**: Re-create the robot account token in Harbor and update the secret in Devtron's "Container Registries" settings. Trigger a new build.

This structured anproach allows an AI agent to systematically diagnose and resolve the most common Kaniko failure mode.
```
---

I will now generate the content for Harbor, Cosign/Syft/Grype, Kyverno, and NeuVector following the same rigorous format. Due to the extensive nature of the request, I will combine the related supply-chain tools for brevity where it makes sense.

---

# Harbor (Deep Dive)

## ## SKILL.md Content

```markdown
# Harbor Quick Reference

### Core Concepts
- **Projects**: Isolated namespaces for images (e.g., `dev`, `staging`, `prod`). Access is controlled per-project.
- **Robot Accounts**: Non-human users for CI/CD. Scoped to projects with granular permissions (push, pull, scan). **Always use robot accounts for automation.**
- **Replication**: Copying images between projects (e.g., promoting `dev` -> `staging`) or other registries.
- **Vulnerability Scanning**: Harbor integrates Trivy to automatically scan images on push. Scan results can be used as a gate.
- **Tag Immutability**: Prevents a tag (like `v1.0.0` or `latest`) from being overwritten. Essential for production projects.
- **Garbage Collection (GC)**: Reclaims storage space by deleting un-tagged (dangling) manifests and layers. **Run this off-peak.**

### Common Operations (CLI / UI)

- **Login (Docker CLI)**:
  `docker login harbor.helixstax.net` (Use your user or a robot account token).
- **Push an Image (Kaniko/Docker)**:
  `docker push harbor.helixstax.net/dev/my-app:sha-abc1234`
- **Create a Robot Account (UI)**:
  1. Go to `Project` -> `Robot Accounts`.
  2. `+ New Robot Account`, give it a name (`devtron-builder`).
  3. Grant permissions: `push repository`, `pull repository`.
  4. Save the token securely. **It is only shown once.**
- **Promote an Image (Replication)**:
  1. Go to `Administration` -> `Replications` -> `+ New Replication Rule`.
  2. **Source**: `harbor.helixstax.net`, **Source Project**: `dev`.
  3. **Destination**: `harbor.helixstax.net`, **Destination Project**: `staging`.
  4. **Trigger**: `On Push` or `Manual`.
  5. **Filter**: By tag (e.g., `release-*`) or label.
- **Check Scan Results (UI)**:
  1. Navigate to Project -> Repository -> Artifact.
  2. Click the artifact digest. The vulnerability report is in the main view.
  3. Look for the "Vulnerabilities" bar graph.

### Troubleshooting

- **Symptom**: `docker push` fails with `denied: requested access to the resource is denied`.
  - **Cause**: The robot account lacks `push` permissions for the target repository.
  - **Fix**: In Harbor, edit the robot account and add `push` permission for that repository/project.
- **Symptom**: Old image is deployed after pushing a new `latest` tag.
  - **Cause**: Kubernetes/ArgoCD is using a cached local image digest because the tag `latest` is mutable. K8s does not re-pull if the image tag is the same unless `imagePullPolicy` is `Always`.
  - **Fix**:
    1. **Best Practice**: Use immutable tags like Git SHAs (`sha-abc1234`). ArgoCD will see the new digest and deploy.
    2. **Prod Hardening**: Enable "Tag Immutability" in the production project settings in Harbor to prevent overwrites.
- **Symptom**: Disk space is full, but images have been deleted.
  - **Cause**: Deleting a tag only removes the tag, not the underlying layers if they are referenced by other tags or untagged. The layers are now "dangling".
  - **Fix**: Run Garbage Collection. Go to `Administration` -> `Garbage Collection` -> `GC Now`. **Warning: Do not run GC during active builds or deployments.** Schedule it for off-peak hours.
```

## ## reference.md Content

```markdown
# Harbor: Deep Reference

### Architecture Overview

Harbor is a collection of microservices packaged as containers.
- **Proxy**: Nginx or Traefik, routes traffic to backend services.
- **Core**: Main API service, handles auth, projects, replication, etc.
- **Registry**: The actual OCI v2 registry that stores image layers.
- **Jobservice**: Executes background jobs like scanning, GC, and replication.
- **Scanner (Trivy)**: The default vulnerability scanner service.
- **Database**: PostgreSQL, stores all metadata.
- **Cache**: Redis, for session and job queue management.

### Robot Accounts
- **Purpose**: To provide programmatic access for CI/CD systems, scanners, etc. More secure than using user accounts.
- **Scopes**:
  - **System**: Can access all projects (admin-level). Use with extreme care.
  - **Project**: Scoped to one or more projects. **This is the recommended type.**
- **Permissions**: Granular control per robot account.
  - `pull`: Pull images.
  - `push`: Push images.
  - `vulnerability`: View scan results.
  - `scanner`: Act as a scanner engine.
  - `delete`: Delete artifacts.
- **Rotation**: Credentials (tokens) do not expire automatically. A process should be in place to rotate them periodically, managed via OpenBao or a similar tool.

### Image Promotion Workflows

1.  **Re-tag and Push (Simple)**
    - CI pulls `dev/app:tag`, re-tags it as `staging/app:tag`, and pushes it.
    - **Pros**: Simple to implement.
    - **Cons**: Breaks signature and attestation chain (the digest changes if re-tagged naively). Requires CI to have credentials for both projects.

2.  **Harbor Replication (Recommended)**
    - **Pull-based**: `staging` project configures a rule to pull from `dev`. `prod` pulls from `staging`.
    - **Push-based**: `dev` project configures a rule to push to `staging`.
    - **Triggers**:
      - `On Push`: Replication starts immediately after a new image is pushed to the source.
      - `Scheduled`: Runs on a cron schedule.
      - `Manual`: Triggered via UI or API.
    - **Filters**: Replicate only specific images using tag wildcards (`release-*`), labels, or resource types.
    - **Flattening**: By default, Harbor preserves the namespace (`dev/app` replicates to `staging/dev/app`). `Override` and `Flatten` options can change this to `staging/app`.
    - **Benefit**: Preserves the image digest, ensuring signatures and SBOMs remain valid.

### Garbage Collection (GC)
- **What it collects**: Manifests that are no longer tagged (`<none>`), and blob layers that are no longer referenced by any manifest in the registry.
- **Process**:
  1. **Read-only mode**: Registry is put into read-only mode to prevent writes.
  2. **Sweep**: The GC job identifies all unreferenced blobs.
  3. **Delete**: The identified blobs are deleted from storage.
  4. **Read-write mode**: Registry returns to normal operation.
- **Safety**: GC is a stop-the-world operation. If a build is pushing layers while GC is running, the push may fail or the image could become corrupted. **Never run GC during business hours or active CI/CD windows.** Schedule it weekly on a weekend night.

### Webhooks
- **Purpose**: Notify external systems of events within Harbor.
- **Events**: `PUSH_ARTIFACT`, `PULL_ARTIFACT`, `DELETE_ARTIFACT`, `SCANNING_COMPLETED`, `SCANNING_FAILED`, etc.
- **Payload**: A JSON object containing information about the event, including the repository, tag, digest, and operator.
- **Use Case**:
  - `SCANNING_COMPLETED` -> n8n webhook -> Checks vulnerability count -> If low, triggers ArgoCD sync via API.
  - `PUSH_ARTIFACT` to `staging` project -> n8n -> Post to Rocket.Chat: "Image ready for QA".

### Harbor API
- **Endpoint**: `https://harbor.helixstax.net/api/v2.0`
- **Authentication**: Basic Auth with user/robot credentials.
- **Key Endpoints**:
  - `GET /projects/{project_name}/repositories/{repository_name}/artifacts/{reference}`: Get artifact details, including scan summary and signature info.
  - `POST /projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/scan`: Trigger a new scan.
  - `GET /projects/{project_name}/repositories/{repository_name}/artifacts/{reference}/additions/vulnerabilities`: Get detailed vulnerability report.
  - `POST /replications`: Trigger a replication rule by its ID.
  - `POST /projects/{project_name}/robot`: Create a new robot account.

### Security Hardening Checklist
- [x] Enforce TLS on the registry endpoint.
- [x] Use project-scoped robot accounts instead of user accounts for automation.
- [x] Configure "Prevent vulnerable images from running" policy with a CRITICAL severity threshold.
- [x] Enable "Tag Immutability" for `staging` and `prod` projects.
- [x] Set Content Trust (Notary) or rely on Cosign/Kyverno for signature enforcement.
- [x] Schedule regular Garbage Collection.
- [x] Limit robot account permissions to the absolute minimum required.
```

## ## examples.md Content

```markdown
# Harbor: Helix Stax Examples

### Example 1: Robot Account Creation via API

This script creates a robot account for a new service `billing-api` in the `dev` project.

```bash
#!/bin/bash

# Configuration for Helix Stax Harbor
HARBOR_URL="https://harbor.helixstax.net"
HARBOR_ADMIN_USER="admin"
# Fetch password from OpenBao or another secret store
HARBOR_ADMIN_PASS=$(bao kv get -field=password secret/harbor/admin)

PROJECT_NAME="dev"
ROBOT_NAME="devtron-billing-api"
REPO_NAME="billing-api"

# Define the permission payload
# access: push and pull on the specific repo billing-api
PAYLOAD=$(cat <<EOF
{
  "name": "${ROBOT_NAME}",
  "disable": false,
  "level": "project",
  "permissions": [
    {
      "kind": "project",
      "namespace": "${PROJECT_NAME}",
      "access": [
        {
          "resource": "repository",
          "action": "push",
          "effect": "allow"
        },
        {
          "resource": "repository",
          "action": "pull",
          "effect": "allow"
        }
      ]
    }
  ]
}
EOF
)

# Use Harbor API to create the robot account
# The response will contain the name and token
curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASS}" \
  --data-raw "${PAYLOAD}" \
  "${HARBOR_URL}/api/v2.0/projects/${PROJECT_NAME}/robots"

# The output will be a JSON object containing the secret token.
# This should be immediately stored in a secret manager like OpenBao.
```

### Example 2: Promotion Replication Rule (dev -> staging)

This defines the replication rule to promote images tagged with `release-*` from the `dev` project to the `staging` project.

**UI Steps:**

1.  Navigate to `Administration` -> `Replication` -> `+ New Replication Rule`.
2.  **Rule Name**: `promote-dev-to-staging`
3.  **Source Registry**: `Local` (harbor.helixstax.net)
4.  **Source Resource Filter**:
    - **Name**: `dev/**` (or more specific, e.g., `dev/user-api`)
    - **Tag**: `release-*`
5.  **Destination Registry**: `Local` (harbor.helixstax.net)
6.  **Destination Namespace**: `staging` (Enter the project name)
7.  **Trigger Mode**: `Manual` (allows for a quality gate before promotion)
8.  Click `Save`.

**API equivalent (`curl`):**

To trigger this rule manually for a specific image:
```bash
# First, find the rule ID from the UI or via GET /replications
REPLICATION_RULE_ID=5

curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "admin:${HARBOR_ADMIN_PASS}" \
  "${HARBOR_URL}/api/v2.0/replications" \
  -d '{ "policy_id": '${REPLICATION_RULE_ID}' }'
```

### Example 3: n8n Workflow for Scan Completion Notification

This workflow listens for a Harbor webhook and posts a summary to Rocket.Chat.

**Trigger Node: Webhook**
- **URL**: n8n generates a URL. Copy this into Harbor's webhook configuration for the `staging` project, for the `SCANNING_COMPLETED` event.

**Function Node: Format Message**
```javascript
// Get the data from the Harbor webhook payload
const eventData = items[0].json.event_data;
const repo = eventData.resources[0].repository;
const tag = eventData.resources[0].tag;
const digest = eventData.resources[0].digest;
const scanOverview = eventData.scan_overview;
const severity = scanOverview.severity;
const criticalCount = scanOverview.summary.critical || 0;
const highCount = scanOverview.summary.high || 0;

let message = `✅ *Scan Completed for ${repo}:${tag}* in Staging\n`;
message += `Severity: *${severity}*\n`;
message += `*Critical*: ${criticalCount}\n`;
message += `*High*: ${highCount}\n`;

if (severity === 'Critical' || severity === 'High') {
  items[0].json.chatMessage = `:warning: ${message} \n*Action required before promoting to production!*`;
  items[0].json.color = "#FF0000"; // Red
} else {
  items[0].json.chatMessage = `:white_check_mark: ${message} \n*Ready for promotion.*`;
  items[0].json.color = "#00FF00"; // Green
}

return items;
```

**Rocket.Chat Node:**
- **Channel**:
