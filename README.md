# Cadent

An open-source endurance training app for tracking and analyzing athletic activities.

## Overview

Cadent is a full-stack, cross-platform application for endurance athletes. It supports recording activities (running, cycling, etc.) with detailed metrics including distance, elevation, speed, and GPS routes. Data can be imported via FIT or GPX files.

**Stack:**
- **Backend**: Go + chi router, PostgreSQL 17
- **Mobile**: Flutter (iOS & Android)
- **Web**: React 19 + TypeScript + TailwindCSS

## Prerequisites

- [Go 1.25+](https://go.dev/)
- [Flutter 3.9+](https://flutter.dev/)
- [Node.js 20+](https://nodejs.org/)
- [Docker](https://www.docker.com/) (for local PostgreSQL)
- [Make](https://www.gnu.org/software/make/)

## Getting Started

### 1. Start the database

```bash
docker compose -f docker-compose.dev.yaml up postgres -d
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 3. Install dependencies

```bash
make install-deps
```

### 4. Run the API

```bash
make run-api
```

The API server starts on port `8080` by default. The web app is embedded and served at `/`.

## Development

### Run the web app (dev server with hot reload)

```bash
make run-web-dev
```

### Run the mobile app

```bash
make run-app
```

### Build for production

```bash
make build          # Backend + mobile APK
make build-api      # Backend only (embeds web app)
make build-web      # Web app only
make build-apk      # Mobile APK only
```

### Docker

```bash
make docker-build-api    # Build Docker image
```

## Testing

```bash
make test           # All unit tests
make test-e2e-api   # End-to-end API tests (requires running server)
```

E2E tests use [Hurl](https://hurl.dev/) and live in the `tests/` directory.

## Project Structure

```
cadent/
├── backend/        # Go REST API
│   ├── internal/   # Handlers, models, DB, storage, geo utilities
│   └── migrations/ # PostgreSQL migrations
├── app/            # Flutter mobile app
├── web/            # React web app
├── tests/          # E2E tests (Hurl)
├── Makefile
├── Dockerfile
└── docker-compose.dev.yaml
```

## API

All API routes are prefixed with `/api`:

| Prefix | Description |
|--------|-------------|
| `/api/auth/*` | Authentication (JWT) |
| `/api/avatar/*` | Avatar management |
| `/api/v1/*` | Protected endpoints (activities, users, training plans) |

## Configuration

See `.env.example` for all available configuration options including database connection, JWT secret, storage backend, and service URLs.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

See [LICENSE](LICENSE) for details.
