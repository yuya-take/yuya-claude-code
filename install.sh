#!/usr/bin/env bash
# yuya-claude-code をカレントプロジェクトの .claude/ に展開する。
#
# 使い方 (プロジェクトルートで実行):
#   curl -fsSL https://raw.githubusercontent.com/yuya-take/yuya-claude-code/main/install.sh | bash
#
# 既存ファイルを上書きしたい場合は末尾を | bash -s -- --force にする
# 廃止済みスキルだけを削除したい場合は | bash -s -- --prune (--force にも含まれる)
set -euo pipefail

REPO="${YUYA_CLAUDE_CODE_REPO:-yuya-take/yuya-claude-code}"
PLUGIN_DIR="my-claude-code"
CLAUDE_DIR="$(pwd)/.claude"
FORCE=0
PRUNE=0

# 統合・改名により廃止したスキル (旧バージョンで展開されたものを片付ける)
DEPRECATED_SKILLS=(
  dev-wt dev-bc                                     # -> dev
  code-review code-review-full code-review-est      # -> rv
  review-pr python-review rust-review security-review # -> rv
  init                                              # -> setup
)

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1; PRUNE=1 ;;
    --prune) PRUNE=1 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "error: git が必要です" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 が必要です (settings.json のマージに使用)" >&2; exit 1; }

# --- 配布元の取得 -------------------------------------------------------------
# リポジトリのクローン内から実行された場合はローカルを使い、それ以外は git clone で取得する
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
if [[ -f "$script_dir/$PLUGIN_DIR/.claude-plugin/plugin.json" ]]; then
  SRC="$script_dir/$PLUGIN_DIR"
  echo "==> ローカルの $SRC から展開します"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  echo "==> https://github.com/$REPO を取得中..."
  git clone --quiet --depth 1 "https://github.com/$REPO.git" "$tmpdir/repo"
  SRC="$tmpdir/repo/$PLUGIN_DIR"
fi

[[ -d "$SRC" ]] || { echo "error: 配布元 $SRC が見つかりません" >&2; exit 1; }

# --- コピー処理 ---------------------------------------------------------------
copied=() updated=() skipped=()

install_file() { # install_file <src> <dst>
  local src="$1" dst="$2" rel="${2#"$CLAUDE_DIR"/}"
  if [[ ! -e "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    copied+=("$rel")
  elif cmp -s "$src" "$dst"; then
    : # 同一内容なので何もしない
  elif [[ "$FORCE" -eq 1 ]]; then
    cp "$src" "$dst"
    updated+=("$rel")
  else
    skipped+=("$rel")
  fi
}

# agents
for f in "$SRC"/agents/*.md; do
  install_file "$f" "$CLAUDE_DIR/agents/$(basename "$f")"
done

# skills
for d in "$SRC"/skills/*/; do
  name="$(basename "$d")"
  for f in "$d"*; do
    [[ -f "$f" ]] && install_file "$f" "$CLAUDE_DIR/skills/$name/$(basename "$f")"
  done
done

# 廃止済みスキルの片付け
deprecated=() pruned=()
for name in "${DEPRECATED_SKILLS[@]}"; do
  dir="$CLAUDE_DIR/skills/$name"
  [[ -d "$dir" ]] || continue
  if [[ "$PRUNE" -eq 1 ]]; then
    rm -rf "$dir"
    pruned+=("skills/$name")
  else
    deprecated+=("skills/$name")
  fi
done

# rules
for f in "$SRC"/rules/*.md; do
  install_file "$f" "$CLAUDE_DIR/rules/$(basename "$f")"
done

# hooks スクリプト
install_file "$SRC/hooks/format-file.sh" "$CLAUDE_DIR/hooks/format-file.sh"
chmod +x "$CLAUDE_DIR/hooks/format-file.sh"

# --- settings.json のマージ (permissions の和集合 + 未設定キーの追加 + format hook の追加) ---
mkdir -p "$CLAUDE_DIR"
SETTINGS_TEMPLATE="$SRC/templates/settings.json" SETTINGS_FILE="$CLAUDE_DIR/settings.json" python3 <<'PY'
import json, os

template_path = os.environ["SETTINGS_TEMPLATE"]
settings_path = os.environ["SETTINGS_FILE"]

with open(template_path) as f:
    template = json.load(f)

settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

changed = []

# permissions.allow / ask の和集合 (既存の順序を保ち、不足分を末尾に追加)
perms = settings.setdefault("permissions", {})
for key in ("allow", "ask"):
    entries = template.get("permissions", {}).get(key, [])
    if not entries:
        continue
    current = perms.setdefault(key, [])
    missing = [e for e in entries if e not in current]
    if missing:
        current.extend(missing)
        changed.append(f"permissions.{key} に {len(missing)} 件追加")

# permissions 以外のトップレベルキー (attribution など) は、未設定の場合だけ追加する
for key, value in template.items():
    if key not in ("permissions", "hooks") and key not in settings:
        settings[key] = value
        changed.append(f"{key} を追加")

# PostToolUse に format-file.sh フックを追加 (既にあれば触らない)
post = settings.setdefault("hooks", {}).setdefault("PostToolUse", [])
if not any("format-file.sh" in h.get("command", "") for m in post for h in m.get("hooks", [])):
    post.append({
        "matcher": "Edit|Write",
        "hooks": [
            {
                "type": "command",
                "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/format-file.sh",
                "timeout": 30,
            }
        ],
    })
    changed.append("hooks.PostToolUse に format-file.sh を追加")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("==> settings.json: " + ("、".join(changed) if changed else "変更なし"))
PY

# --- 結果報告 -----------------------------------------------------------------
echo ""
echo "展開先: $CLAUDE_DIR"
echo "  新規コピー: ${#copied[@]} 件"
[[ "$FORCE" -eq 1 ]] && echo "  上書き更新: ${#updated[@]} 件"
if [[ ${#skipped[@]} -gt 0 ]]; then
  echo "  スキップ (内容が異なる既存ファイル): ${#skipped[@]} 件"
  for f in "${skipped[@]}"; do echo "    - $f"; done
  echo "  ※ 上書きするには --force を付けて再実行してください"
fi
if [[ ${#pruned[@]} -gt 0 ]]; then
  echo "  廃止済みスキルを削除: ${#pruned[@]} 件"
  for f in "${pruned[@]}"; do echo "    - $f"; done
fi
if [[ ${#deprecated[@]} -gt 0 ]]; then
  echo "  廃止済みスキルが残っています (/dev, /rv, /setup に統合済み): ${#deprecated[@]} 件"
  for f in "${deprecated[@]}"; do echo "    - $f"; done
  echo "  ※ 削除するには --prune を付けて再実行してください"
fi
echo ""
echo "完了。プロジェクトに合わせたカスタマイズは Claude Code 内で /setup スキルを実行してください。"
