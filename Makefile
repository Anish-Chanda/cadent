# ==== Config ====
FRONTEND_DIR = app
BACKEND_DIR = backend
GO_APP_NAME = api
GO_BUILD_DIR = bin
GO_MAIN = main

include .env.example

# common stuff
install:
	@echo "Installing go dependencies..."
	cd $(BACKEND_DIR) && go mod tidy
	@echo "Installing flutter dependencies..."
	cd $(FRONTEND_DIR) && flutter pub get

test:
	cd $(BACKEND_DIR) && go test ./... --cover

build:
	@echo "Building Go application..."
	cd $(BACKEND_DIR) && go build -o ../$(GO_BUILD_DIR)
	@echo "Building Flutter application (Apk)..."
	cd $(FRONTEND_DIR) && flutter build apk

# API specific stuff
run-api:
	@echo "Running Go application..."
	./bin/backend