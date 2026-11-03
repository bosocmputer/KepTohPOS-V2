---
name: db-migration
description: Use when modifying database schemas, creating tables, adding columns, writing migrations, or tuning SQL/ORM queries (ใช้เมื่อแก้ไขโครงสร้างฐานข้อมูลหรือรัน Migration)
---
# Safe Database Schema & Zero-Downtime Migration (`supabase/agent-skills` + `jeffallan/claude-skills`)

> **Reference Architecture:** [`supabase/agent-skills`](https://github.com/supabase/agent-skills) (`supabase-postgres-best-practices`) & [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) (`database-architect`, `postgres-pro`, `sql-pro`)

## 1. The Iron Law
> **ZERO-DOWNTIME EXPAND & CONTRACT — NEVER LOCK TABLES OR CORRUPT PRODUCTION DATA.**

## 2. Core Workflow

### Step 1: Schema & Access Pattern Analysis (`database-architect` / `sql-pro`)
1. Inspect existing migration files, ORM schema (`schema.prisma`, `drizzle`, `entities`), and query patterns before generating DDL.
2. Verify foreign key relationships, cascade behavior (`ON DELETE RESTRICT` vs `CASCADE`), and multi-tenant isolation (`tenant_id` / `user_id`).

### Step 2: Lock-Safe Migration Design (`Expand & Contract Pattern`)
1. **Immutable History:** Never edit or delete a migration file that has already been committed. Always create a new forward migration.
2. **Safe Column Additions:** When adding a column to an existing table, make it `NULLABLE` or provide a safe constant `DEFAULT` so existing rows and running code do not fail.
3. **Destructive DDL Gate:** Never execute `DROP TABLE`, `DROP COLUMN`, or `TRUNCATE` without explicit written confirmation from the user.
4. **PostgreSQL / SQL Dialect Safety (`supabase-postgres-best-practices`):**
   - Never generate invalid syntax such as `ADD CONSTRAINT IF NOT EXISTS` in PostgreSQL.
   - Use `CREATE INDEX CONCURRENTLY` when indexing large production tables to avoid blocking writes.

### Step 3: Indexing, Security & Query Optimization (`postgres-pro`)
1. **Foreign Key & Filter Indexing:** Every foreign key (`user_id`, `order_id`, `organization_id`) and frequent `WHERE` / `JOIN` / `ORDER BY` column must have an index.
2. **Eliminate N+1 Queries:** Never run database queries inside a `for` / `map` loop. Use `WHERE id IN (...)`, `JOIN`, or ORM batch loading (`include` / `preload`).
3. **ACID Transactions:** Wrap multi-table mutations (e.g., inventory deduction + order creation, wallet balance transfers) inside a database transaction (`$transaction` / `BEGIN...COMMIT`).
4. **Row-Level Security (RLS) & Bounded Queries:** Always scope queries by tenant/owner and apply `LIMIT` / cursor pagination. Never use unbounded `SELECT *` on growing tables.

## 3. Constraints (`MUST DO` / `MUST NOT DO`)
- **MUST** use parameterized queries / prepared statements for all inputs.
- **MUST** wrap multi-step state mutations in a single transaction.
- **MUST NOT** modify previously committed migration files.
- **MUST NOT** execute queries inside loops (N+1) or return unbounded table scans.
