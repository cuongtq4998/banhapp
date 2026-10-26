# Multi-stage image for linux/amd64 (ADR-0001, deployment.md section 2).
# Built in CI, never on the host. Build context is the repository root, because
# the package depends on ../contracts/swift:
#   docker build --platform linux/amd64 -f backend/Dockerfile .
# The base image tags below are the major.minor line, not a digest; CI should
# pin digests once the first image is published.

ARG SWIFT_VERSION=6.2
ARG RUNTIME_IMAGE=ubuntu:24.04

# ---- build stage ----
FROM swift:${SWIFT_VERSION}-noble AS build
WORKDIR /build

# Resolve dependencies first so this layer is cached until a manifest changes.
COPY backend/Package.swift backend/Package.resolved ./backend/
COPY contracts/swift ./contracts/swift
WORKDIR /build/backend
RUN swift package resolve

# Package.swift declares the AppTests target, and SwiftPM rejects a manifest
# whose target directory is missing even when only the App product is built.
# The build stage is not shipped, so copying the tests costs no image size.
COPY backend/Sources ./Sources
COPY backend/Tests ./Tests
RUN swift build -c release --static-swift-stdlib \
    && mkdir -p /staging \
    && cp "$(swift build -c release --show-bin-path)/App" /staging/App

# ---- runtime stage ----
FROM ${RUNTIME_IMAGE}
# CA certificates are needed for TLS to the hosted database.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /app --shell /usr/sbin/nologin vapor

WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging/App ./App
# SQL migrations are read from ./db/migrations by `App migrate`.
COPY --chown=vapor:vapor backend/db ./db
# Product images and the privacy page, served from ./assets (api.md 4.5, 4.6).
COPY --chown=vapor:vapor backend/assets ./assets

USER vapor
# The host injects PORT (deployment.md section 3); EXPOSE is documentation only.
EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve"]
