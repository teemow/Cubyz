# syntax=docker/dockerfile:1.7
#
# Cubyz dedicated server image (build-from-source)
#
# Builds the headless Cubyz server from source using Zig and packages it on a
# minimal Alpine runtime. Cross-compiles via Zig itself, so the build always
# runs on the host architecture (BUILDPLATFORM) and never under QEMU.
#
# Usage:
#   docker build -t cubyz-server:dev .
#   docker build -t cubyz-server:dev --build-arg TARGET=aarch64 .

ARG ALPINE_VERSION=3.21

# -----------------------------------------------------------------------------
# Build stage
# -----------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS build

# TARGET is the Zig CPU architecture for the produced binary (x86_64 | aarch64).
# When building with buildx, derive it from TARGETARCH unless TARGET is set
# explicitly. Falls back to x86_64 for plain `docker build` invocations.
ARG TARGETARCH
ARG TARGET
ARG ZIG_BUILD_FLAGS="-Doptimize=ReleaseFast -Drelease=true"

RUN apk add --no-cache \
        bash \
        curl \
        git \
        tar \
        xz

WORKDIR /src

# Copy only the files needed to fetch the toolchain first so the Zig download
# layer can be cached across source edits.
COPY .zigversion ./
COPY scripts/install_compiler_linux.sh scripts/install_compiler_linux.sh

# Resolve the effective TARGET (build-arg wins, otherwise map TARGETARCH, then
# fall back to the host arch). The Zig compiler itself is downloaded for the
# *build host* arch (the install script keys off `uname -m`); cross-compilation
# is handled by `-Dtarget` further down.
RUN set -eux; \
    if [ -z "${TARGET:-}" ]; then \
        case "${TARGETARCH:-}" in \
            amd64) TARGET=x86_64 ;; \
            arm64) TARGET=aarch64 ;; \
            "")    TARGET="$(uname -m)" ;; \
            *)     echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
        esac; \
    fi; \
    echo "${TARGET}" > /tmp/cubyz_target; \
    ./scripts/install_compiler_linux.sh

COPY . .

# Build the Cubyz binary statically against musl for the requested target.
RUN set -eux; \
    TARGET="$(cat /tmp/cubyz_target)"; \
    ./compiler/zig/zig build \
        --error-style minimal \
        -Dtarget="${TARGET}-linux-musl" \
        ${ZIG_BUILD_FLAGS}

# -----------------------------------------------------------------------------
# Runtime stage
# -----------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION}

LABEL org.opencontainers.image.title="cubyz-server" \
      org.opencontainers.image.description="Headless Cubyz dedicated server" \
      org.opencontainers.image.source="https://github.com/PixelGuys/Cubyz" \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

# `iproute2` provides `ss`, used by the Helm chart's UDP liveness probe.
# `tini` reaps zombies and forwards SIGTERM cleanly during pod shutdown.
RUN apk add --no-cache \
        ca-certificates \
        iproute2 \
        tini \
    && addgroup -g 1000 cubyz \
    && adduser -D -u 1000 -G cubyz -h /app cubyz \
    && mkdir -p /data \
    && chown -R cubyz:cubyz /app /data

WORKDIR /app

COPY --from=build --chown=cubyz:cubyz /src/zig-out/bin/Cubyz /app/Cubyz
COPY --from=build --chown=cubyz:cubyz /src/assets/cubyz /app/assets/cubyz

# Ship a sensible default launchConfig.zon for the headless server. The Helm
# chart overlays its own copy via a ConfigMap mount, so this file only matters
# for plain `docker run` usage.
RUN printf '%s\n' \
        '.{' \
        '    .cubyzDir = "/data",' \
        '    .autoEnterWorld = "world",' \
        '    .headlessServer = true,' \
        '    .createIfMissing = true,' \
        '    .worldPreset = "cubyz:default",' \
        '}' > /app/launchConfig.zon \
    && chown cubyz:cubyz /app/launchConfig.zon

USER cubyz

VOLUME ["/data"]
EXPOSE 47649/udp

ENTRYPOINT ["/sbin/tini", "--", "/app/Cubyz"]
