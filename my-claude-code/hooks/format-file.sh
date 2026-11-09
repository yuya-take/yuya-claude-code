#!/bin/bash
# Edit/Write の直後に、編集されたファイルだけをフォーマットする。
#
# - 未使用 import / 変数の自動削除はしない。Claude は「import を追加 → 次の Edit で使う」
#   順に編集することが多く、間で消されると壊れるため (ruff: F401/F841 を unfixable、
#   biome: linter を無効化してフォーマットと import 整列だけ行う)
# - プロジェクトにインストール済みのツールだけを使う。npx の自動インストールは
#   別パッケージを取得する恐れがあるため使わない
# - 失敗しても編集自体は止めない (常に exit 0)

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
fi

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# 指定ディレクトリから上に向かって、相対パス $2 が存在する最初のディレクトリを返す
find_up() {
  local dir="$1" target="$2"
  while [ "$dir" != "/" ]; do
    if [ -e "$dir/$target" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

FILE_DIR=$(cd "$(dirname "$FILE_PATH")" && pwd)

case "$FILE_PATH" in
  *.py)
    # uv workspace では .venv がワークスペースルートにあるため、上に向かって探す
    if VENV_DIR=$(find_up "$FILE_DIR" ".venv/bin/ruff"); then
      RUFF="$VENV_DIR/.venv/bin/ruff"
    elif command -v ruff >/dev/null 2>&1; then
      RUFF=ruff
    else
      exit 0
    fi
    PROJECT_DIR=$(find_up "$FILE_DIR" "pyproject.toml") || PROJECT_DIR="$FILE_DIR"
    cd "$PROJECT_DIR" || exit 0
    "$RUFF" format --quiet "$FILE_PATH" 2>/dev/null
    "$RUFF" check --fix --quiet --unfixable F401,F841 "$FILE_PATH" >/dev/null 2>&1
    ;;
  *.ts | *.tsx | *.js | *.jsx | *.json | *.css)
    BIN_DIR=$(find_up "$FILE_DIR" "node_modules/.bin/biome") || exit 0
    cd "$BIN_DIR" || exit 0
    "$BIN_DIR/node_modules/.bin/biome" check --write --linter-enabled=false \
      --no-errors-on-unmatched "$FILE_PATH" >/dev/null 2>&1
    ;;
esac

exit 0
