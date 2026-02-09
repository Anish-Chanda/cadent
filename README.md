# Cadent README

## Overview

Cadent is an open‑source, privacy‑first running and cycling tracker designed for athletes, coaches, and developers who need accurate performance analytics without subscription walls or data‑harvesting platforms.

This README serves both **users** and **developers**, providing onboarding, hosting, device connectivity, and contribution guidelines.

---

## Key Features

* Live GPS activity tracking
* Offline cache + sync on reconnect
* Valhalla‑based high‑accuracy map matching
* BLE device integration (HRM, cadence)
* Secure authentication (Argon2id + OAuth2)
* Self‑hosting support (1 CPU core, 2GB RAM minimum)
* Shareable activity visualizations
* Open‑source API + integration layer for device vendors

---

## User Quick Start

1. **Download Cadent** *(store deployment coming soon)*
2. Create an account or sign in with OAuth
3. Grant permissions for GPS + sensors
4. Start an activity → run or ride
5. Pause/finish → view detailed maps + stats

### Optional: Pair a Heart Rate Monitor

* Navigate to **Settings → Devices → Bluetooth**
* Select **Pair New Device**
* Supported profiles include: heart rate, cadence sensors

---

## Self‑Hosting Setup

### Minimum Requirements

* 1 CPU core
* 2GB RAM
* PostgreSQL 18+
* Optional: Valhalla + tile server (for local map processing)

### Deployment via Docker

```bash
docker compose up --build
```

Backend, PostgreSQL, Valhalla, and tile server will start.

---

## Developer Setup

### Prerequisites

* Flutter SDK
* Dart
* Go 1.22+
* PostgreSQL 18+

### Install & Run

```bash
git clone https://github.com/sdmay26-14/cadent
cd cadent/mobile
flutter pub get
flutter run
```

Backend:

```bash
cd cadent/server
make dev
```

---

## API Overview

REST endpoints are documented in the `/docs` module.

* `/auth/*` — login/signup, OAuth
* `/activities/*` — create, stream, view, share
* `/devices/*` — BLE integration helpers

---

## BLE Integration

Cadent supports:

* Heart rate monitors
* Cadence sensors
* Cycling wearables

BLE reconnect logic ensures data persistence during movement and signal loss.

---

## Privacy & Data Ownership

Cadent does **not** monetize or share fitness data. Users may:

* Host locally
* Disable cloud sync entirely
* Export/delete all data

Data is stored using encryption standards and secure authentication flows.

---

## Testing Overview

* **Unit tests** for backend + Flutter service logic
* **Integration tests** for BLE, routes, and auth
* **System tests** validating full activity recording
* **k6 performance tests** for backend throughput

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit pull request with passing test suite

```bash
git checkout -b feature/new-module
```

We welcome:

* Device integration plugins
* Map style enhancements
* UI improvements

---

## License

Cadent is fully open‑source, built for transparency and community collaboration.

---

## Contact & Support

Team Email: [sdmay26-14@iastate.edu](mailto:sdmay26-14@iastate.edu)
Website: sdmay26-14.sd.ece.iastate.edu

For bug reports, open a GitHub issue with reproduction steps.
