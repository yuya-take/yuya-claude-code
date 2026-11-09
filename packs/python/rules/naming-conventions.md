---
paths:
  - "**/*.py"
---

# Naming Conventions

- **Files/Functions**: `snake_case`
- **Classes**: `PascalCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Arrays**: Must end with `_list` suffix (e.g., `user_list`, not `users`) — プロジェクト固有の規約（Python標準ではない）
- **Booleans**: Start with `is_` prefix (e.g., `is_deleted`, `is_active`)
- **UseCase Models**: End with `View` suffix (e.g., `UserProfileView`)
- **Repository Interfaces**: `{Entity}Repository` (in domain/)
- **Repository Implementations**: `{Entity}RepositoryImpl` (in adapter/)
