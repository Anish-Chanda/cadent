# Variables
API_VERSION = v0.9.0
MOBILE_VERSION = v0.9.0

# ==== Config ====
FRONTEND_DIR = app
BACKEND_DIR = backend
GO_APP_NAME = api
GO_BUILD_DIR = bin
GO_MAIN = main

-include .env

.PHONY: install-deps test build build-api build-apk run-api run-app docker-build-api set-version clean-version dev-up dev-down test-e2e-process test-e2e-clean test-e2e-api help
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)


# ==== Version Management ====
BUILD_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

set-version:
	@echo "Injecting version information..."
	@sed -i 's/version = ""/version = "$(MOBILE_VERSION)"/g' $(FRONTEND_DIR)/lib/utils/app_version.dart
	@sed -i 's/buildHash = ""/buildHash = "$(BUILD_HASH)"/g' $(FRONTEND_DIR)/lib/utils/app_version.dart
	@sed -i 's/Version   = ""/Version   = "$(API_VERSION)"/g' $(BACKEND_DIR)/version.go
	@sed -i 's/BuildHash = ""/BuildHash = "$(BUILD_HASH)"/g' $(BACKEND_DIR)/version.go

clean-version:
	@echo "Restoring version files to empty values..."
	@sed -i 's/version = "$(MOBILE_VERSION)"/version = ""/g' $(FRONTEND_DIR)/lib/utils/app_version.dart
	@sed -i 's/buildHash = "$(BUILD_HASH)"/buildHash = ""/g' $(FRONTEND_DIR)/lib/utils/app_version.dart
	@sed -i 's/Version   = "$(API_VERSION)"/Version   = ""/g' $(BACKEND_DIR)/version.go
	@sed -i 's/BuildHash = "$(BUILD_HASH)"/BuildHash = ""/g' $(BACKEND_DIR)/version.go

# ==== Common Targets ====

install-deps: ## Install dependencies for backend and mobile app
	@echo "Installing go dependencies..."
	cd $(BACKEND_DIR) && go mod tidy
	@echo "Installing flutter dependencies..."
	cd $(FRONTEND_DIR) && flutter pub get

test: ## Run backend and flutter tests
	cd $(BACKEND_DIR) && go test ./... --cover
	cd $(FRONTEND_DIR) && flutter test

build: set-version ## Build both backend and mobile app
	@echo "Building Go application..."
	cd $(BACKEND_DIR) && go build -o ../$(GO_BUILD_DIR)
	@echo "Building Flutter application (Apk)..."
	cd $(FRONTEND_DIR) && flutter build apk
	@$(MAKE) clean-version

# ==== Docker Helpers ====
dev-up: ## Start development docker containers (postgres), Note: it is recomended to run the backend binary directly
	docker compose -f docker-compose.dev.yaml up postgres -d

dev-down: ## Stop development docker containers
	docker compose -f docker-compose.dev.yaml down

docker-build-api: ## Build backend API Docker image with version info
	@echo "Building Docker image with version $(API_VERSION) and build hash $(BUILD_HASH)..."
	docker build \
		--build-arg API_VERSION=$(API_VERSION) \
		--build-arg BUILD_HASH=$(BUILD_HASH) \
		-t cadent-api:$(API_VERSION) \
		-t cadent-api:latest \
		.


# ==== Backend API Targets ====

build-api: set-version ## Build backend API binary
	@echo "Building Go application..."
	cd $(BACKEND_DIR) && go build -o ../$(GO_BUILD_DIR)/$(GO_APP_NAME) .
	@$(MAKE) clean-version

run-api: build-api ## Build and run backend API server
	@set -a && [ -f ./.env ] && . ./.env && set +a && \
		./bin/$(GO_APP_NAME)

# ==== Mobile App Targets ====

build-apk: set-version ## Build mobile app APK
	@echo "Building Flutter application (APK)..."
	cd $(FRONTEND_DIR) && flutter build apk
	@$(MAKE) clean-version

run-app: set-version ## Run mobile app on connected device
	@echo "Running Flutter application..."
	cd $(FRONTEND_DIR) && flutter run
	@$(MAKE) clean-version

# ==== E2E Testing Targets ====

# Optional flags for hurl tests (e.g., make test-e2e-api HURL_FLAGS="--jobs 1 --verbose")
HURL_FLAGS ?=

test-e2e-api: ## Run hurl e2e tests
	@echo "Running hurl e2e tests..."
	@hurl --test $(HURL_FLAGS) --glob "tests/api/**/*.hurl"