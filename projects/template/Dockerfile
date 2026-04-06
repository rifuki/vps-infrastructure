# Stage 1: Builder
FROM rust:1.88-slim-bookworm AS builder

# BINARY_NAME must match the [[bin]] name or [package] name in Cargo.toml
ARG BINARY_NAME
RUN test -n "$BINARY_NAME" || (echo "ERROR: BINARY_NAME build arg is required" && exit 1)

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy manifests first for better caching
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY src ./src

# Build release binary and rename to generic name
RUN cargo build --release && \
    cp target/release/${BINARY_NAME} target/release/app

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binary from builder (always named 'app')
COPY --from=builder /app/target/release/app /app/app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["/app/app"]
