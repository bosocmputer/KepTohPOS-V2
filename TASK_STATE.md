# TASK_STATE.md

- **Branch:** `flutter/f1-domain`
- **Completed (F0 + F1 Preparation + F1 Domain & Parity Unit Tests):**
  - Merged `origin/claude/determined-bell-k5ps5l` (plan v0.4).
  - Renamed 23 Figma reference screenshots in `design/figma/`, removed redundant zip archive, and documented mapped/missing screens in `design/figma/README.md`.
  - Split `app/lib/core/theme/tokens.dart` into `raw_tokens.dart` + `tokens.dart` (single `figma` brand, `light`/`dark`/`system` modes) and removed `app/assets/mock/mock_data.json`.
  - Ported pure-Dart domain models, permissions (`ROLE`, `VIEWS`), pricing (`calcOrder`, `tableTotals`, `mergeTotals`, `orderOf`, `tableDue`, `tableTimer`, `sentLines`), settlement (`sendRound`, `adjustSent`, `settle`), inventory/profit ledger (`computeLedger`), and deterministic `rng`/`seed` into `app/lib/domain/`.
  - Added JS-parity unit tests in `app/test/unit/order_settle_test.dart` and `app/test/unit/seed_ledger_test.dart` (`flutter analyze` 0 issues, `flutter test` 11/11 passed).
- **In Progress / Broken:** None.
- **Next Immediate Step:** Start **F2** (`docs/llms/flutter-plan.md`): implement data layer (`drift` SQLite tables/DAOs + `shared_preferences` + repositories + first-run seed from `assets/mock/*.json`) and repository tests.
