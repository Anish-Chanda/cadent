# ==== Config ====
FRONTEND_DIR = app
BACKEND_DIR = backend
GO_APP_NAME = api
GO_BUILD_DIR = bin
GO_MAIN = main

include .env.example

# common stuff
install:
	@echo "Installing dependencies..."
	cd $(BACKEND_DIR) && go mod tidy

test:
	cd $(BACKEND_DIR) && go test ./... --cover

build:
	@echo "Building Go application..."
	cd $(BACKEND_DIR) && go build -o ../$(GO_BUILD_DIR)

# API specific stuff
run-api:
	@echo "Running Go application..."
	./bin/backend