#!/bin/bash
# Edit/Write の直後に、編集された TypeScript / JavaScript / JSON / CSS ファイルだけを biome でフォーマットする。
#
# - linter は動かさず、フォーマットと import の並べ替えだけを行う。未使用 import の自動削除は、
#   Claude が「import を追加 → 次の Edit で使う」順に編集したときに壊れるため
# - プロジェクトにインストール済みの biome だけを使う。npx の自動インストールは
#   `biome` という名前の別パッケージを取得してしまうため使わない
# - 失敗しても編集自体は止めない (常に exit 0)

INPUT=$(cat)
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
fi

case "$FILE_PATH" in
  *.ts | *.tsx | *.js | *.jsx | *.json | *.css) ;;
  *) exit 0 ;;
esac
[ -f "$FILE_PATH" ] || exit 0

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
BIN_DIR=$(find_up "$FILE_DIR" "node_modules/.bin/biome") || exit 0
cd "$BIN_DIR" || exit 0
"$BIN_DIR/node_modules/.bin/biome" check --write --linter-enabled=false \
  --no-errors-on-unmatched "$FILE_PATH" >/dev/null 2>&1

exit 0
