#!/bin/bash
# Auto-format files after Edit/Write tool use
# Finds the nearest service directory and runs formatting from there

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Find nearest directory containing the given marker file
find_project_root() {
  local dir="$1"
  local marker="$2"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/$marker" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

if [[ "$FILE_PATH" == *.py ]]; then
  PROJECT_DIR=$(find_project_root "$(dirname "$FILE_PATH")" "pyproject.toml")
  if [ -n "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR" && uv run ruff format "$FILE_PATH" 2>/dev/null && uv run ruff check --fix "$FILE_PATH" 2>/dev/null
  fi
elif [[ "$FILE_PATH" == *.ts || "$FILE_PATH" == *.tsx || "$FILE_PATH" == *.js || "$FILE_PATH" == *.jsx ]]; then
  PROJECT_DIR=$(find_project_root "$(dirname "$FILE_PATH")" "package.json")
  if [ -n "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR" && npx biome check --write "$FILE_PATH" 2>/dev/null
  fi
fi

exit 0
