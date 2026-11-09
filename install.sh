#!/usr/bin/env bash
# yuya-claude-code の pack を、カレントプロジェクトの .claude/ に展開する。
#
# 使い方 (プロジェクトルートで実行):
#   curl -fsSL https://raw.githubusercontent.com/yuya-take/yuya-claude-code/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --packs dev-flow,python   # pack を指定 (依存する pack は自動で追加)
#   curl -fsSL .../install.sh | bash -s -- --list                    # pack の一覧と既定の選択を表示
#
# オプション:
#   --packs <a,b,...|all>  入れる pack。省略時は前回入れた pack、初回は core,review,dev-flow と
#                          プロジェクトから検出した言語の pack (python / frontend / rust)
#   --list                 pack の一覧と、このプロジェクトでの選択を表示して終了する
#   --only <種類,...>      展開する種類を絞る (skills,agents,rules,hooks,settings)
#   --force                手元で変更されたファイルも上書きし、--prune も有効にする
#   --prune                不要になったファイル (外した pack の分、廃止したスキル・agent) を削除する
#   --src <dir>            配布元リポジトリのパス (省略時はこのスクリプトの隣、無ければ GitHub から取得)
set -euo pipefail

REPO="${YUYA_CLAUDE_CODE_REPO:-yuya-take/yuya-claude-code}"

command -v python3 >/dev/null 2>&1 || { echo "error: python3 が必要です" >&2; exit 1; }

# --- 配布元の決定 ---------------------------------------------------------------
SRC=""
prev=""
for arg in "$@"; do
  [[ "$prev" == "--src" ]] && SRC="$arg"
  prev="$arg"
done

if [[ -z "$SRC" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || pwd)"
  if [[ -f "$script_dir/.claude-plugin/marketplace.json" && -d "$script_dir/packs" ]]; then
    SRC="$script_dir"
  else
    command -v git >/dev/null 2>&1 || { echo "error: git が必要です" >&2; exit 1; }
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    echo "==> https://github.com/$REPO を取得中..."
    git clone --quiet --depth 1 "https://github.com/$REPO.git" "$tmpdir/repo"
    SRC="$tmpdir/repo"
  fi
fi
[[ -d "$SRC/packs" ]] || { echo "error: 配布元 $SRC に packs/ が見つかりません" >&2; exit 1; }

# --- 展開 (本体は Python) ---------------------------------------------------------
python3 - "$SRC" "$(pwd)" "$@" <<'PY'
import argparse
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

src = Path(sys.argv[1]).resolve()
project = Path(sys.argv[2]).resolve()

ap = argparse.ArgumentParser(prog="install.sh")
ap.add_argument("--packs")
ap.add_argument("--list", action="store_true")
ap.add_argument("--only")
ap.add_argument("--force", action="store_true")
ap.add_argument("--prune", action="store_true")
ap.add_argument("--src")
args = ap.parse_args(sys.argv[3:])
prune = args.prune or args.force

KINDS = ["skills", "agents", "rules", "hooks", "settings"]
BASE_PACKS = ["core", "review", "dev-flow"]
# 言語 pack の自動検出に使うファイル
DETECT = {
    "python": ["pyproject.toml", "requirements.txt", "setup.py"],
    "frontend": ["package.json"],
    "rust": ["Cargo.toml"],
}
SKIP_DIRS = {".git", ".claude", "node_modules", ".venv", "venv", "target", "dist", "build", "__pycache__"}
# 導入記録 (manifest) の無い旧バージョンで展開され、その後に廃止・統合したもの
DEPRECATED = [
    "skills/dev-wt", "skills/dev-bc",                                   # -> dev
    "skills/code-review", "skills/code-review-full", "skills/code-review-est",
    "skills/review-pr", "skills/python-review", "skills/rust-review",
    "skills/security-review",                                           # -> rv
    "skills/init",                                                      # -> setup
    "agents/clean-arch-guard.md",                                       # -> python-reviewer
    "agents/migration-checker.md",                                      # -> database-reviewer
    "hooks/format-file.sh",                                             # -> format-python.sh / format-frontend.sh
]

claude = project / ".claude"
manifest_path = claude / ".yuya-claude-code.json"
settings_path = claude / "settings.json"


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_json(path, default):
    path = Path(path)
    if not path.exists():
        return default
    with open(path) as f:
        return json.load(f)


# --- pack の読み込み ---------------------------------------------------------------
marketplace = load_json(src / ".claude-plugin" / "marketplace.json", {})
order = [p["name"] for p in marketplace.get("plugins", []) if p.get("source", "").startswith("./packs/")]
packs = {}
for name in order:
    pdir = src / "packs" / name
    meta = load_json(pdir / ".claude-plugin" / "plugin.json", {})
    deps = [d if isinstance(d, str) else d["name"] for d in meta.get("dependencies", [])]
    packs[name] = {"dir": pdir, "description": meta.get("description", ""), "deps": [d.split("@")[0] for d in deps]}


def detect_languages():
    found = set()
    for root, dirs, files in os.walk(project):
        depth = len(Path(root).relative_to(project).parts)
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and depth < 3]
        for pack, markers in DETECT.items():
            if any(m in files for m in markers):
                found.add(pack)
    return [p for p in order if p in found]


def resolve(requested):
    resolved = []

    def visit(name, chain):
        if name not in packs:
            die(f"pack '{name}' はありません (一覧: {', '.join(order)})")
        if name in chain:
            die(f"pack の依存が循環しています: {' -> '.join(chain + [name])}")
        if name in resolved:
            return
        for dep in packs[name]["deps"]:
            visit(dep, chain + [name])
        resolved.append(name)

    for name in requested:
        visit(name, [])
    return sorted(resolved, key=order.index)


manifest = load_json(manifest_path, {"packs": [], "files": {}})
if args.packs:
    requested = order if args.packs.strip() == "all" else [p.strip() for p in args.packs.split(",") if p.strip()]
    reason = "--packs で指定"
elif manifest.get("packs"):
    requested = manifest["packs"]
    reason = "前回の選択"
else:
    detected = detect_languages()
    requested = BASE_PACKS + detected
    reason = "既定 (core, review, dev-flow)" + (f" + 検出した言語: {', '.join(detected)}" if detected else "")
selection = resolve(requested)

if args.list:
    print("pack 一覧 (* はこのプロジェクトでの選択):\n")
    for name in order:
        mark = "*" if name in selection else " "
        deps = f"  [依存: {', '.join(packs[name]['deps'])}]" if packs[name]["deps"] else ""
        print(f" {mark} {name:<9} {packs[name]['description']}{deps}")
    print(f"\n選択の根拠: {reason}")
    sys.exit(0)

kinds = KINDS if not args.only else [k.strip() for k in args.only.split(",") if k.strip()]
for k in kinds:
    if k not in KINDS:
        die(f"--only に指定できるのは {', '.join(KINDS)} です")


def kind_of(rel):
    return rel.split("/", 1)[0]


# --- 展開するファイルの一覧 -------------------------------------------------------------
planned = {}  # 展開先の相対パス -> 配布元のファイル
for name in selection:
    pdir = packs[name]["dir"]
    for kind in ("skills", "agents", "rules", "hooks"):
        if kind not in kinds or not (pdir / kind).is_dir():
            continue
        for path in sorted((pdir / kind).rglob("*")):
            if not path.is_file() or (kind == "hooks" and path.name == "hooks.json"):
                continue
            if kind in ("agents", "rules") and path.suffix != ".md":
                continue
            rel = f"{kind}/{path.relative_to(pdir / kind).as_posix()}"
            if rel in planned:
                die(f"{rel} が複数の pack に含まれています")
            planned[rel] = path

old_files = manifest.get("files", {})
new_files = {rel: h for rel, h in old_files.items() if kind_of(rel) not in kinds}
copied, updated, skipped = [], [], []

for rel, path in planned.items():
    dst = claude / rel
    src_hash = sha(path)
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, dst)
        copied.append(rel)
    elif sha(dst) == src_hash:
        pass
    elif args.force or old_files.get(rel) == sha(dst):
        # 手元で変更されていない (前回このスクリプトが入れたまま) なら、そのまま更新してよい
        shutil.copyfile(path, dst)
        updated.append(rel)
    else:
        skipped.append(rel)
        continue
    if kind_of(rel) == "hooks":
        dst.chmod(0o755)
    new_files[rel] = src_hash

# --- 不要になったファイル -------------------------------------------------------------
stale, kept_modified, removed = [], [], []
for rel, recorded in old_files.items():
    if kind_of(rel) not in kinds or rel in planned:
        continue
    dst = claude / rel
    if not dst.exists():
        new_files.pop(rel, None)
    elif sha(dst) != recorded:
        kept_modified.append(rel)
        new_files.pop(rel, None)
    else:
        # 削除するまでは記録に残す (後から --prune で消せるように)
        stale.append(rel)
        new_files[rel] = recorded

# 選んでいない pack のファイルが、配布元と同じ内容で残っている場合 (導入記録の無い旧バージョンで
# 全 pack を入れていた場合など) も、このスクリプトが入れたものとして扱う
for name in order:
    if name in selection:
        continue
    pdir = packs[name]["dir"]
    for kind in ("skills", "agents", "rules", "hooks"):
        if kind not in kinds or not (pdir / kind).is_dir():
            continue
        for path in sorted((pdir / kind).rglob("*")):
            if not path.is_file() or (kind == "hooks" and path.name == "hooks.json"):
                continue
            rel = f"{kind}/{path.relative_to(pdir / kind).as_posix()}"
            dst = claude / rel
            if rel in planned or rel in old_files or not dst.is_file():
                continue
            if sha(dst) == sha(path):
                stale.append(rel)
                new_files[rel] = sha(path)

legacy = [rel for rel in DEPRECATED
          if kind_of(rel) in kinds and rel not in planned and rel not in old_files and (claude / rel).exists()]


def remove(rel):
    target = claude / rel
    if target.is_dir():
        shutil.rmtree(target)
    else:
        target.unlink()
    parent = target.parent
    while parent != claude and parent.exists() and not any(parent.iterdir()):
        parent.rmdir()
        parent = parent.parent
    removed.append(rel)
    new_files.pop(rel, None)


if prune:
    for rel in stale + legacy:
        remove(rel)

# --- settings.json のマージ ----------------------------------------------------------
settings_changes = []
if "settings" in kinds or "hooks" in kinds:
    settings = load_json(settings_path, {})
    before = json.dumps(settings, sort_keys=True)

    if "settings" in kinds:
        for name in selection:
            frag = load_json(packs[name]["dir"] / "project-settings.json", {})
            for key, entries in frag.get("permissions", {}).items():
                current = settings.setdefault("permissions", {}).setdefault(key, [])
                missing = [e for e in entries if e not in current]
                if missing:
                    current.extend(missing)
                    settings_changes.append(f"permissions.{key} に {len(missing)} 件 ({name})")
            for key, value in frag.items():
                if key not in ("permissions", "hooks") and key not in settings:
                    settings[key] = value
                    settings_changes.append(f"{key} を追加 ({name})")

    if "hooks" in kinds:
        # 削除したフックスクリプトの登録を外す
        removed_scripts = {Path(rel).name for rel in removed if kind_of(rel) == "hooks"}
        for event, groups in list(settings.get("hooks", {}).items()):
            for group in groups:
                group["hooks"] = [h for h in group.get("hooks", [])
                                  if not any(s in h.get("command", "") for s in removed_scripts)]
            settings["hooks"][event] = [g for g in groups if g.get("hooks")]
            if not settings["hooks"][event]:
                del settings["hooks"][event]
        if removed_scripts:
            settings_changes.append(f"hooks から {', '.join(sorted(removed_scripts))} の登録を削除")

        # pack の hooks.json を、プロジェクトの .claude/hooks/ を指す形にして登録する
        for name in selection:
            spec = load_json(packs[name]["dir"] / "hooks" / "hooks.json", {})
            for event, groups in spec.get("hooks", {}).items():
                registered = settings.setdefault("hooks", {}).setdefault(event, [])
                for group in groups:
                    for hook in group.get("hooks", []):
                        command = hook.get("command", "").replace("${CLAUDE_PLUGIN_ROOT}", "$CLAUDE_PROJECT_DIR/.claude")
                        script = Path(command.replace('"', "").split()[0]).name
                        if any(script in h.get("command", "") for g in registered for h in g.get("hooks", [])):
                            continue
                        registered.append({"matcher": group.get("matcher", ""), "hooks": [dict(hook, command=command)]})
                        settings_changes.append(f"hooks.{event} に {script} を登録 ({name})")

    if json.dumps(settings, sort_keys=True) != before:
        claude.mkdir(parents=True, exist_ok=True)
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2, ensure_ascii=False)
            f.write("\n")

# --- 導入記録 ------------------------------------------------------------------------
claude.mkdir(parents=True, exist_ok=True)
with open(manifest_path, "w") as f:
    json.dump({"packs": selection, "files": dict(sorted(new_files.items()))}, f, indent=2, ensure_ascii=False)
    f.write("\n")

# --- 結果報告 ------------------------------------------------------------------------
print(f"==> 配布元: {src}")
print(f"==> 展開先: {claude}")
print(f"==> pack: {', '.join(selection)}  ({reason})")
if args.only:
    print(f"==> 種類: {', '.join(kinds)}")
print(f"  新規: {len(copied)} 件 / 更新: {len(updated)} 件")
if skipped:
    print(f"  スキップ (手元で変更されているため): {len(skipped)} 件")
    for rel in skipped:
        print(f"    - {rel}")
    print("  ※ 配布元の内容で上書きするには --force を付けて再実行してください")
if removed:
    print(f"  削除: {len(removed)} 件")
    for rel in removed:
        print(f"    - {rel}")
pending = [rel for rel in stale + legacy if rel not in removed]
if pending:
    print(f"  不要になったファイル (外した pack の分・廃止したもの): {len(pending)} 件")
    for rel in pending:
        print(f"    - {rel}")
    print("  ※ 削除するには --prune を付けて再実行してください")
if kept_modified:
    print(f"  不要になったが手元で変更されているため残したファイル: {len(kept_modified)} 件")
    for rel in kept_modified:
        print(f"    - {rel}")
print("  settings.json: " + ("、".join(settings_changes) if settings_changes else "変更なし"))
print("\n完了。プロジェクトに合わせたカスタマイズは、Claude Code で /setup を実行してください。")
PY
