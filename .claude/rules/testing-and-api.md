---
paths:
  - "**/*.{test,spec}.{js,ts,tsx,py}"
  - "**/*_test.{go,dart,py}"
  - "**/test_*.py"
  - "test/**/*.dart"
  - "src/**/routes/**"
  - "src/**/controllers/**"
  - "src/**/services/**"
  - "src/app/api/**"
  - "internal/**/handler*/**"
  - "internal/**/service*/**"
  - "lib/**/services/**"
  - "lib/**/repositories/**"
---
# Testing Standards (`obra/superpowers` TDD) & API Security Conventions

> **Reference Architecture:** [`obra/superpowers`](https://github.com/obra/superpowers) (`skills/test-driven-development/SKILL.md`), [`goldbergyoni/nodebestpractices`](https://github.com/goldbergyoni/nodebestpractices), & OWASP API Security Top 10

## 1. Real Testing Discipline (`obra/superpowers` TDD Protocol)
- **Real Code Over Tautological Mocks:**
  - Test the actual business function and real data structures. **Never mock the function or module under test**, and avoid heavy mocking unless isolating external network/payment/email I/O.
- **Verify RED / Regression Test First (For Bug Fixes):**
  - When fixing a bug, write or run a test that reproduces the exact failure first, watch it fail for the expected reason (`Verify RED`), and then apply the minimal fix to turn it green (`Verify GREEN`).
- **AAA Structure & Core Coverage:**
  - Structure every test with clear `// Arrange`, `// Act`, and `// Assert` phases covering:
    1. **Happy Path:** Expected valid input produces expected output.
    2. **Boundary / Edge Case:** Zero, negative, empty, `null`/`undefined`, or duplicate inputs.
    3. **Regression / Error Case:** Invalid inputs throw or return the documented error code.
- **Test Integrity (Zero Cheating):**
  - Never weaken assertions, delete failing tests, or add `.skip` / `.only` to make a test suite pass.

## 2. API Design, Boundary Validation & OWASP Security
- **Validate at the Door:** Validate and sanitize all request payloads (`body`, `query`, `params`) at the controller/route boundary using schema validators (e.g., Zod, TypeBox, Pydantic, class-validator) before invoking service logic.
- **Object-Level Authorization (OWASP API1 - BOLA/IDOR Prevention):**
  - Every read/write endpoint that takes a resource ID (`/:id`) must verify that the authenticated user/tenant owns or has permission to access that specific resource.
- **Strict Separation of Concerns:**
  - **Controller / Route Handler:** Parse HTTP request, validate schema, check auth, call Service, return HTTP status code (`200/201`, `400`, `401`, `403`, `404`, `409`, `500`).
  - **Service Layer:** Pure business rules and transaction orchestration (never pass raw HTTP `req`/`res` objects into services).
  - **Data Access / Repository:** Parameterized queries only; never expose sensitive fields (`passwordHash`, secret tokens) in API responses.
- **No Silent Error Swallowing:** Never write empty `catch (err) {}` blocks. Log or propagate structured errors with deterministic status codes.
