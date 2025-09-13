# Build stage
FROM golang:1.25.1-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY backend/ ./backend/

# Build the application
WORKDIR /app/backend
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ../bin/api .

# Final stage
FROM alpine:latest

# TODO: Install ca-certificates for HTTPS requests, when we handle it, maybe
# RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -D -s /bin/sh -u 1001 -G appgroup appuser

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/bin/api .

# Create avatars directory
RUN mkdir -p /app/avatars && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Run the application
CMD ["./api"]
