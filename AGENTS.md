# TKT Parcel Agent Guide

## Scope

- Read `PROJECT_CONTEXT.md`, `TASK_LOG.md`, `ARCHITECTURE.md`, `DATABASE.md`, and `README.md` before broad changes.
- Keep changes task-focused. Preserve unrelated working-tree edits.
- Use the existing Riverpod, repository, service, and feature-first patterns unless an architecture change is explicitly approved.

## Safety

- Never drop/reset a database, delete database files, truncate tables, or run broad destructive SQL.
- Make schema changes only through additive/data-preserving Drift or Supabase migrations with a rollback/backup plan.
- Never commit or print passwords, tokens, API keys, service-role keys, or signing credentials. Supply the public Supabase anon key through a local environment or `--dart-define` only.
- Do not edit generated Drift files manually. Regenerate them with build_runner after table or DAO changes.

## Product invariants

- Supabase issues official tracking IDs; do not generate authoritative IDs on-device.
- Server-created parcels are never deleted to recover from a local save or print failure. Pull and reprint the existing parcel.
- Old local-only parcels remain local unless a separate import plan is explicitly approved.
- Preserve the package-provided printer connection flow and route permissions through the existing helper.

## Verification and documentation

- Format changed Dart files and run focused tests, then `flutter analyze` and broader tests in proportion to risk.
- Visually inspect print/label changes with the bundled Myanmar font and the exact output aspect ratio.
- Update `TASK_LOG.md` for completed work and tests. Update the matching context, architecture, database, and README documentation when behavior changes.
