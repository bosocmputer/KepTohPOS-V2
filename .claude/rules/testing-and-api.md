---
description: "(กฎบังคับใช้เทสต์จริง ห้ามสร้างข้อมูลหลอก และตรวจความปลอดภัย API)"
paths:
  - "**/*.{test,spec}.{js,ts,tsx,py}"
  - "**/*_test.{go,dart,py}"
  - "**/test_*.py"
  - "**/test/**/*.dart"
  - "**/integration_test/**/*.dart"
  - "**/routes/**"
  - "**/controllers/**"
  - "**/services/**"
  - "**/repositories/**"
  - "**/datasources/**"
  - "**/core/sync/**"
  - "**/core/data/**"
  - "**/bloc*/**"
  - "**/supabase/**"
  - "src/app/api/**"
  - "internal/**/handler*/**"
  - "internal/**/service*/**"
---
# Testing & API Security Hard Invariants

## 1. Real Testing Discipline (`obra/superpowers` TDD)
- **Real Code Over Tautological Mocks:** Test actual business functions and real data structures. **Never mock the function or module under test**; mock only external network/payment/hardware I/O.
- **Verify RED ➔ GREEN (For Bug Fixes):** Reproduce the exact failure with a test first (`Verify RED`), then apply the minimal code fix (`Verify GREEN`).
- **Required Edge Coverage:** Cover happy path, boundary/edge cases (`0`, negative, empty, `null`, duplicate), and explicit error cases.
- **Zero Test Tampering:** Never weaken assertions, delete failing tests, or add `.skip` / `.only` to pass a suite.

## 2. API Boundary & OWASP Security Invariants
- **Validate at Boundary:** Validate request inputs (`body`, `query`, `params`) at the route/RPC boundary before invoking business logic.
- **BOLA / IDOR Tenant Ownership (`OWASP API1`):** Every read/write endpoint or RPC taking a resource ID (`:id`) must verify tenant/user ownership (`shop_id`, `tenant_id`, `user_id`) in the query/RLS check.
- **Parameterized Queries & Secret Stripping:** Never interpolate raw strings into SQL, and never expose sensitive fields (`passwordHash`, tokens, keys) in responses.
- **No Silent Error Swallowing:** Never write empty `catch (err) {}` blocks; propagate or map structured errors explicitly.
