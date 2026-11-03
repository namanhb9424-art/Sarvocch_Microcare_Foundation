# SARVOOCCH — Immediate Next Engineering Actions

**Date:** 3 November 2026  
**Status:** In Progress  

---

## Immediate Action Checklist

1. [x] Phase 0 & 1: Repository discovery, audits, and parity matrix generated in `docs/`.
2. [x] Live web server verified running on port 5001.
3. [ ] **Action 1**: Update application metadata and strings to standardized **SARVOOCCH** spelling (Web templates, `app.py`, `pubspec.yaml`, Flutter AppBar titles).
4. [ ] **Action 2**: Implement the 5 missing Flutter parity screens:
   - `lib/screens/branches/branches_screen.dart`
   - `lib/screens/hrm/hrm_screen.dart`
   - `lib/screens/whatsapp/whatsapp_screen.dart`
   - `lib/screens/pregrt/group_apply_screen.dart`
   - `lib/widgets/doc_viewers/document_sheet.dart`
5. [ ] **Action 3**: Update Flutter `routes` and `CustomDrawer` to include the new screens according to user role permissions.
6. [ ] **Action 4**: Implement synthetic seed generator script supporting Small, Medium, and Large profiles.
7. [ ] **Action 5**: Create CI/CD GitHub Actions workflow `.github/workflows/ci.yml`.
8. [ ] **Action 6**: Create `Dockerfile` and `docker-compose.yml`.
9. [ ] **Action 7**: Run full test suites (`flutter test`, `flutter analyze`, Python checks), commit changes, push to branch, and update PR #1.
