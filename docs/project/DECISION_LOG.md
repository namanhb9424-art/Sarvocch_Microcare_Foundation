# SARVOOCCH — Architecture & Engineering Decision Log (ADR)

**Application Name:** SARVOOCCH  
**Date:** 3 November 2026  

---

## Decision Entries

### ADR-001: Standardization to Exact Product Name SARVOOCCH
- **Context**: The existing codebase contained variations ("Sarvocch", "Sarvocch Microcare Foundation", "Microfin Portal").
- **Decision**: Strictly adopt **SARVOOCCH** across all documentation, metadata, user-facing titles, and code references while preserving official brand logo and teal styling.
- **Status**: ACCEPTED & ENFORCED.

### ADR-002: Modular Monolith Retention for Web Backend
- **Context**: Evaluated whether to rewrite Flask into FastAPI or microservices.
- **Decision**: Retain and strengthen the Flask modular architecture. A full framework rewrite on the eve of deployment poses unacceptable regression risks. Strengthening the existing operational engine ensures zero feature regression.
- **Status**: ACCEPTED.

### ADR-003: Standalone Offline-First SQLite Engine for Mobile App
- **Context**: Field officers operate in rural and semi-urban centers with intermittent mobile connectivity.
- **Decision**: Maintain offline SQLite relational storage inside Flutter using `sqflite`, syncing with the server via an atomic idempotency log (`sync_log`).
- **Status**: ACCEPTED.

### ADR-004: In-Memory Database Fallback for Headless Unit Tests
- **Context**: Running `flutter test` without a connected Android/iOS device fails when native SQLite platform channels are invoked.
- **Decision**: In `DatabaseHelper`, fall back to `sqflite_common_ffi` with in-memory database during test runs. All 6 automated user flow test suites execute reliably in headless CI environments.
- **Status**: ACCEPTED.
