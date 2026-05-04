


# Web build stage
FROM node:20-alpine AS web-builder

WORKDIR /app

# Copy package files and install dependencies
COPY web/package*.json ./web/
WORKDIR /app/web
RUN npm ci

# Copy web source and build
COPY web/ .
RUN npm run build

# Go build stage
FROM golang:1.25.1-alpine AS builder

# Version arguments
ARG API_VERSION=dev
ARG BUILD_HASH=unknown
ARG ENABLE_GO_COVERAGE=false

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy backend source code
COPY backend/ ./backend/

# Copy built web files from web-builder stage
COPY --from=web-builder /app/backend/web/dist ./backend/web/dist

# Build the application with version injection.
# ENABLE_GO_COVERAGE is used by CI E2E tests to collect coverage from the API binary.
WORKDIR /app/backend
RUN set -eux; \
    if [ "$ENABLE_GO_COVERAGE" = "true" ]; then \
        COVERPKG="$(go list ./... | tr '\n' ',' | sed 's/,$//')"; \
        CGO_ENABLED=0 GOOS=linux go build \
            -cover \
            -coverpkg="$COVERPKG" \
            -ldflags "-X main.Version=${API_VERSION} -X main.BuildHash=${BUILD_HASH}" \
            -o ../bin/api .; \
    else \
        CGO_ENABLED=0 GOOS=linux go build \
            -a -installsuffix cgo \
            -ldflags "-X main.Version=${API_VERSION} -X main.BuildHash=${BUILD_HASH}" \
            -o ../bin/api .; \
    fi

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -D -s /bin/sh -u 1001 -G appgroup appuser

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/bin/api .

# Create runtime directories
RUN mkdir -p /app/avatars /app/go-cover && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Run the application
CMD ["./api"]
