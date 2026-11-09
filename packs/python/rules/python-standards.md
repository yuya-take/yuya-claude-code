---
paths:
  - "**/*.py"
---

# Python Development Standards

- **Package Manager**: Always use `uv` (not pip/poetry) - workspace-based monorepo
- **Type Hints**: Modern syntax (`str | None` not `Optional[str]`)
- **Formatting**: Run lint/format before commits（例: `make lint`, `uv run ruff check --fix && uv run ruff format`）
- **Type Checking**: 作業を終える前に、プロジェクトの型チェッカー（`ty` / `pyright` / `mypy` のうち設定されているもの）のエラーを解消する（lint と同じ優先度）
- **Data Structures**: Avoid raw `dict` - define Pydantic models for type safety (API request/response, config, etc.)
- **Testing**: Comprehensive async tests with pytest
- **Models**: Use Pydantic/SQLModel for all data structures
- **Comments**: Write source code comments in Japanese
- **Python Version**: `pyproject.toml` の `requires-python` に従う（それより新しい構文や標準ライブラリを使わない）
