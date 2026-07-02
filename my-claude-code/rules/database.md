---
paths:
  - "**/migrations/**"
  - "**/adapter/model/**/*.py"
---

# Database Standards

## Multi-Schema Strategy

- **Shared schema**: User management, tenant/subscription, group hierarchy (shared across services)
- **Service-specific schema**: Service-specific tables (e.g., device config, analysis settings, alert rules)
- **Public schema**: Shared tables, extensions

## Centralized Migrations

All migrations are centralized in `infrastructure/migrations/` (NOT per-service):
- All services share one Alembic environment
- Multi-schema support configured in `alembic.ini`
- Auto-generation from SQLModel models

## Migration Workflow

1. Modify SQLModel models in service's `adapter/model/`
2. `cd infrastructure/migrations`
3. `make migration MSG="add new tables"`
4. Review migration in `versions/`
5. `make upgrade`

## Database Patterns

- **Multi-tenancy (optional)**: If multi-tenant, isolate data by `tenant_id`
- **UUID Primary Keys**: Better distribution across services
- **Soft Deletes**: `is_deleted` boolean flags
- **Timestamps**: `created_at`/`updated_at` via mixins
- **Hierarchical Data**: Groups use `parent_group_id` for tree structures
- **Foreign Keys**: Strict constraints for data integrity
