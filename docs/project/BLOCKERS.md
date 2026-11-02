# SARVOOCCH — Active & Historical Blockers Register

**Date:** 3 November 2026  
**Status:** ZERO ACTIVE CRITICAL BLOCKERS  

---

## 1. Active Blockers
- **None**. The engineering path is clear and unblocked.

---

## 2. Historical & Environmental Blockers (Resolved)

| ID | Issue | Impact | Resolution | Status |
| :--- | :--- | :--- | :--- | :--- |
| **BLK-01** | macOS Port 5000 occupied | Flask web server could not bind to default port 5000 | Configured `PORT=5001` with background daemonization. | **RESOLVED** |
| **BLK-02** | Flutter native sqflite plugin crash in test runner | `flutter test` threw `MissingPluginException` for SQLite path | Implemented `sqflite_common_ffi` in-memory fallback in `DatabaseHelper`. | **RESOLVED** |
| **BLK-03** | Navigation replacement trapped mobile users | Pressing back exited app on sub-screens | Replaced `pushReplacementNamed` with `pushNamed` in `CustomDrawer`. | **RESOLVED** |
