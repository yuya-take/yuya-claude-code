---
paths:
  - "**/*.py"
---

# Python Development Standards

- **Package Manager**: Always use `uv` (not pip/poetry) - workspace-based monorepo
- **Type Hints**: Modern syntax (`str | None` not `Optional[str]`)
- **Formatting**: Run lint/format before commits（例: `make lint`, `uv run ruff check --fix && uv run ruff format`）
- **Type Checking**: Fix all Pylance errors before completing code changes (same priority as lint)
- **Data Structures**: Avoid raw `dict` - define Pydantic models for type safety (API request/response, config, etc.)
- **Testing**: Comprehensive async tests with pytest
- **Models**: Use Pydantic/SQLModel for all data structures
- **Comments**: Write source code comments in Japanese
- **Python Version**: 3.11-3.13
