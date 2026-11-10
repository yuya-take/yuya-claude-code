#!/usr/bin/env python3
"""UI の「AI っぽさ」の候補を、コードから機械的に拾う。

判定はしない。出力は候補の一覧で、直すかどうかは /unslop-design が文脈を見て決める。

  scan.py [<ファイル | ディレクトリ> ...] [--base <ref>] [--summary] [--include-ui] [--exclude <glob>] [--limit <件数>]

  --base        <ref> との分岐点から追加・変更した行（未コミット分と未追跡ファイルを含む）だけを見る
  --summary     候補の行ではなく、ファイルごとの件数を多い順に出す（画面の一覧を作るため）
  --include-ui  既定で除外している components/ui/（shadcn/ui の基盤コンポーネント）も見る
"""

import argparse
import fnmatch
import os
import re
import subprocess
import sys
from collections import Counter

MARKUP = {".tsx", ".jsx", ".ts", ".js", ".mjs", ".vue", ".svelte", ".astro", ".html", ".mdx"}
STYLE = {".css", ".scss", ".sass", ".less", ".pcss"}

EXCLUDES = [
    "node_modules/*", "*/node_modules/*", ".next/*", "*/.next/*", "dist/*", "*/dist/*",
    "build/*", "*/build/*", "out/*", "*/out/*", "coverage/*", "*/coverage/*",
    "storybook-static/*", "*/storybook-static/*", "*/orval/*", "*/__generated__/*", ".claude/*",
    "*.min.*", "*.d.ts", "*.test.*", "*.spec.*", "*.stories.*", "*.config.*",
]
UI_DIRS = ["components/ui/*", "*/components/ui/*"]
MAX_BYTES = 1_000_000

JA = "\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff"
PALETTE = "slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose"
COLOR_PREFIX = "bg|text|border(?:-[trblxyse])?|ring|ring-offset|fill|stroke|from|via|to|outline|divide|decoration|shadow|placeholder|accent|caret"
COLOR_FN = r"(?:#|rgba?\(|hsla?\(|oklch\(|oklab\(|lab\(|lch\(|hwb\(|color-mix\()"
CSS_COLOR = r"#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch|oklab|lab|lch|hwb)\("
THEME_BLOCK = re.compile(r":root|@theme|\.dark\b|\[data-theme|:host|color-scheme")

CATEGORIES = ["基盤", "装飾", "動き", "文字", "文言", "状態"]

# (カテゴリ, 名前, 正規表現, 対象, 文脈次第か, 見方)
# 対象: markup = コンポーネントや HTML、style = CSS、both = 両方（@apply の Tailwind クラスも拾うため）
RULES = [
    ("基盤", "色の任意値",
     r"\b(?:" + COLOR_PREFIX + r")-\[" + COLOR_FN, "both", False,
     "意味の合う色トークン（bg-primary、text-muted-foreground など）に寄せる"),
    ("基盤", "パレット色の直指定",
     r"\b(?:" + COLOR_PREFIX + r")-(?:(?:" + PALETTE + r")-(?:50|[1-9]00|950)|white|black)\b", "both", False,
     "テーマやダークモードに追従しない。色トークンに寄せ、合うものが無い状態色はトークンの追加を提案する"),
    ("基盤", "スケール外の任意値",
     r"(?<![\w-])-?(?:p[xytrblse]?|m[xytrblse]?|gap(?:-[xy])?|space-[xy]|w|h|size|min-[wh]|max-[wh]|inset(?:-[xy])?"
     r"|top|left|right|bottom|text|leading|tracking|rounded(?:-[a-z]{1,2})?|translate-[xy]|basis)"
     r"-\[(?!var\(|calc\(|#|rgba?\(|hsla?\(|okl|lab\(|lch\(|hwb\(|color-mix)", "both", True,
     "余白・文字サイズ・角丸のスケールの段階に寄せる"),
    ("基盤", "色コードの直書き",
     r"(?<!href=)(?<!to=)[\"'`(:\s]#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})(?![\w-])", "markup", False,
     "色トークン（CSS 変数）を参照する"),
    ("装飾", "グラデーション",
     r"\bbg-(?:gradient-to-[a-z]{1,2}|linear-[\w\[\]/-]+|radial\b|radial-[\w\[\]/-]+|conic\b|conic-[\w\[\]/-]+)"
     r"|\b(?:repeating-)?(?:linear|radial|conic)-gradient\(", "both", False,
     "ブランドとして定義されたものでなければ単色に"),
    ("装飾", "グラデーション文字",
     r"(?=.*\bbg-clip-text\b)(?=.*\btext-transparent\b)|background-clip:\s*text", "both", False,
     "単色の文字色に"),
    ("装飾", "光彩・色付きの影",
     r"\bshadow-\[|\bdrop-shadow-\[|\bshadow-(?:" + PALETTE + r")-\d|\btext-shadow\b"
     r"|box-shadow:[^;]*\b0(?:px)?\s+0(?:px)?\s+\d{2,}px", "both", False,
     "影は中立色の小さいものか、境界線に"),
    ("装飾", "ぼかしの装飾",
     r"\bblur-(?:2xl|3xl|\[\d{2,}px\])|filter:\s*blur\(\s*\d{2,}px", "both", False,
     "背景のぼかした色の円などは消す"),
    ("装飾", "すりガラス",
     r"\bbackdrop-blur\b|\bbackdrop-blur-|backdrop-filter:\s*blur", "both", True,
     "固定ヘッダーなど、下の内容を透かす必要があるもの以外は外す"),
    ("装飾", "絵文字",
     "[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B50\u2B55]", "markup", False,
     "アイコンならプロジェクトのアイコンセットに、飾りなら消す"),
    ("装飾", "バッジ",
     r">\s*(?:NEW|New|新着|Beta|BETA|β|AI)\s*<", "markup", True,
     "本当に必要な 1 箇所以外は外す"),
    ("動き", "繰り返す動き",
     r"\banimate-(?:pulse|ping|bounce)\b|\banimate-\[[^\]]*infinite|animation[\w-]*:[^;]*\binfinite\b", "both", True,
     "読み込み中・ライブ表示など、状態が変わっているもの以外は止める"),
    ("動き", "ホバーで動く",
     r"\b(?:hover|group-hover):-?(?:scale|translate-[xy]|rotate)-", "both", False,
     "ホバーは色や背景の変化に"),
    ("動き", "transition-all",
     r"\btransition-all\b|transition:\s*all\b", "both", False,
     "変える属性だけを transition させる（transition-colors など）"),
    ("文字", "極端に太い文字",
     r"\bfont-(?:extrabold|black)\b|font-weight:\s*(?:800|900)\b", "both", False,
     "階層はサイズと色でつける"),
    ("文字", "字間を広げた大文字",
     r"(?=.*\buppercase\b)(?=.*\btracking-(?:wide|wider|widest|\[))", "both", False,
     "普通の表記にする"),
    ("文字", "斜体",
     r"\bitalic\b|font-style:\s*italic", "both", True,
     "和文には斜体が無い。強調は色や太さで"),
    ("文字", "小さい文字の字間を詰めている",
     r"(?=.*\btracking-(?:tight|tighter|\[-))(?=.*\btext-(?:xs|sm|base)\b)", "both", False,
     "小さい文字は詰めない"),
    ("文字", "和文の詰まった行間",
     r"(?=.*\bleading-(?:none|tight)\b)(?=.*[" + JA + r"])", "markup", True,
     "本文は leading-relaxed 前後に"),
    ("文言", "感嘆符",
     r"！|[" + JA + r"A-Za-z]!!|[" + JA + r"]!(?!=)|>[^<>{}]*[A-Za-z]!(?!=)[^<>{}]*<|[A-Za-z]![\"'`]", "markup", False,
     "平叙文にする"),
    ("文言", "煽り語",
     r"革新的|圧倒的|次世代|シームレス|最先端|爆速|魔法のよう|劇的に|まったく新しい|究極の|最強の|誰でも簡単|たった\d|AI搭載|AIが自動で"
     r"|(?i:\b(?:supercharge|seamless(?:ly)?|revolutioni[sz]e|game[- ]?chang(?:er|ing)|next[- ]gen(?:eration)?"
     r"|cutting[- ]edge|blazing(?:ly)?[- ]fast|effortless(?:ly)?|ai[- ]powered)\b)", "markup", True,
     "何ができるかを具体的に書く"),
    ("文言", "挨拶の見出し",
     r"ようこそ|おかえりなさい|(?i:\bwelcome back\b)", "markup", True,
     "画面や対象の名前を見出しにする"),
    ("文言", "裏付けの要る実績",
     r"\d[\d,.]*\s*(?:万|千)?\s*(?:社|人|名|件|ユーザー)\s*(?:以上|突破|超|が導入|が利用)|満足度\s*\d"
     r"|(?:業界|国内|世界)(?:初|最大|No\.?\s?1|ナンバーワン)|(?i:\b(?:trusted|loved|used) by\b)"
     r"|\d[\d,.]*[kK]?\+\s*(?:社|人|(?i:users|teams|companies|customers))", "markup", False,
     "事実か確認する。事実なら出典か時点を添え、違えば消す"),
    ("文言", "行き先の分からないリンク",
     r">\s*(?:こちら|ここ|ここをクリック|詳しくはこちら|(?i:click here|here|learn more))\s*<", "markup", True,
     "行き先や操作を書く"),
    ("文言", "見出し・ボタン末尾の句点",
     r"<(?:button|Button|label|Label|h[1-6]|CardTitle|DialogTitle|SheetTitle|TabsTrigger|Badge)\b[^>]*>\s*[^<>{}]{1,30}。\s*<",
     "markup", False,
     "末尾の「。」を外す"),
    ("文言", "「…」で終わるプレースホルダ",
     r"placeholder=[\"'{`][^\"'`]*(?:\.\.\.|…)", "markup", True,
     "入力例を短く書く"),
    ("状態", "フォーカスの表示を消している",
     r"(?=.*\boutline-(?:none|hidden)\b)(?!.*\b(?:focus-visible|focus|focus-within):(?:ring|outline|border|shadow))"
     r"|outline:\s*(?:none|0)\s*[;}]", "both", False,
     "focus-visible:ring などで、キーボード操作のフォーカスが見えるようにする"),
    ("状態", "alt の無い画像",
     r"<img\b(?![^>]*\balt=)[^>]*>", "markup", False,
     "内容を表す alt を付ける（飾りなら alt=\"\"）"),
]
CSS_RULE = ("基盤", "テーマ外の色の直書き", "テーマ（@theme / :root）に定義したトークンを var() で参照する")

COMPILED = [(cat, name, re.compile(rx), target) for cat, name, rx, target, _, _ in RULES]
HINTS = {name: (weak, hint) for _, name, _, _, weak, hint in RULES}
HINTS[CSS_RULE[1]] = (False, CSS_RULE[2])
CSS_TOKEN = re.compile(r"[{};]|" + CSS_COLOR)


def git(root, *args):
    result = subprocess.run(["git", "-c", "core.quotePath=false", *args], cwd=root, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git " + " ".join(args) + " が失敗しました")
    return result.stdout


def repo_root():
    try:
        return git(None, "rev-parse", "--show-toplevel").strip()
    except (RuntimeError, FileNotFoundError):
        return None


def list_files(root, target):
    """target（root からの相対パス。"" は全体）以下のファイルを、root からの相対パスで返す。"""
    if root:
        args = ["ls-files", "-co", "--exclude-standard"]
        if target:
            args += ["--", target]
        return git(root, *args).splitlines()
    base = os.path.join(os.getcwd(), target)
    found = []
    for current, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d not in {"node_modules", ".git", ".next", "dist", "build"}]
        for name in files:
            found.append(os.path.relpath(os.path.join(current, name), os.getcwd()))
    return found


def changed_lines(root, base):
    """分岐点から追加・変更した行を {パス: 行番号の集合 | None（全行）} で返す。"""
    try:
        point = git(root, "merge-base", base, "HEAD").strip()
    except RuntimeError:
        point = base
    changes = {}
    path = None
    for line in git(root, "diff", "-U0", "--no-color", "--no-ext-diff", point, "--").splitlines():
        if line.startswith("+++ "):
            name = line[4:]
            path = None if name == "/dev/null" else (name[2:] if name.startswith("b/") else name)
            if path is not None:
                changes.setdefault(path, set())
        elif line.startswith("@@") and path is not None:
            match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
            if match:
                start, count = int(match.group(1)), int(match.group(2) or 1)
                changes[path].update(range(start, start + count))
    for name in git(root, "ls-files", "--others", "--exclude-standard").splitlines():
        changes[name] = None
    return changes


def excluded(path, patterns):
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def is_comment(stripped, style):
    if stripped.startswith("/*"):
        return True
    if style:
        return stripped.startswith("* ") and "{" not in stripped
    return stripped.startswith(("//", "* ", "{/*", "<!--"))


def snippet(line, start):
    text = line.strip()
    if len(text) <= 120:
        return text
    offset = max(0, start - (len(line) - len(line.lstrip())) - 40)
    piece = text[offset:offset + 120]
    return ("…" if offset else "") + piece + ("…" if offset + 120 < len(text) else "")


def scan_file(path, name, lines_filter, findings):
    """path を読み、候補を name（表示用の相対パス）で findings に足す。"""
    ext = os.path.splitext(path)[1].lower()
    style = ext in STYLE
    try:
        if os.path.getsize(path) > MAX_BYTES:
            return False
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return False

    wanted = (lambda number: True) if lines_filter is None else (lambda number: number in lines_filter)
    for number, line in enumerate(lines, 1):
        if not wanted(number) or is_comment(line.strip(), style):
            continue
        if style and line.strip().startswith(("--", "$")):
            continue  # トークンの定義そのものは対象外
        for cat, rule, regex, target in COMPILED:
            if target == "markup" and style or target == "style" and not style:
                continue
            match = regex.search(line)
            if match:
                findings.append((name, number, cat, rule, snippet(line, match.start())))

    if style:
        # テーマの定義（:root / @theme / .dark）と、カスタムプロパティの定義の外にある色だけを拾う
        stack, buffer = [], ""
        for number, line in enumerate(lines, 1):
            position = 0
            for match in CSS_TOKEN.finditer(line):
                buffer += line[position:match.start()]
                position = match.end()
                token = match.group(0)
                if token == "{":
                    stack.append(buffer.strip())
                    buffer = ""
                elif token == "}":
                    if stack:
                        stack.pop()
                    buffer = ""
                elif token == ";":
                    buffer = ""
                elif (wanted(number) and not any(THEME_BLOCK.search(s) for s in stack)
                      and not buffer.strip().startswith(("--", "$", "@"))
                      and not is_comment(line.strip(), True)):
                    findings.append((name, number, CSS_RULE[0], CSS_RULE[1], snippet(line, match.start())))
            buffer += line[position:] + "\n"
    return True


def main():
    parser = argparse.ArgumentParser(description="UI の「AI っぽさ」の候補をコードから拾う")
    parser.add_argument("paths", nargs="*", help="対象のファイルやディレクトリ（省略時はリポジトリ全体）")
    parser.add_argument("--base", help="この ref との分岐点から変更した行だけを見る")
    parser.add_argument("--include-ui", action="store_true", help="components/ui/ も対象にする")
    parser.add_argument("--exclude", action="append", default=[], help="除外する glob（複数指定可）")
    parser.add_argument("--limit", type=int, default=300, help="表示する候補の上限（既定 300）")
    parser.add_argument("--summary", action="store_true", help="ファイルごとの件数だけを多い順に出す")
    args = parser.parse_args()

    root = repo_root()
    if args.base and not root:
        sys.exit("--base は git リポジトリの中でだけ使えます")
    base_dir = root or os.getcwd()

    def relative(path):
        return os.path.relpath(os.path.abspath(path), base_dir)

    # 対象: {パス: 見る行（None は全行）}。ディレクトリを展開したものだけに除外パターンを適用する
    targets, explicit = {}, set()
    include_ui = args.include_ui
    if args.paths:
        for given in args.paths:
            rel = relative(given)
            if os.path.isfile(given):
                targets[rel] = None
                explicit.add(rel)
            elif os.path.isdir(given):
                if "components/ui" in rel.replace(os.sep, "/"):
                    include_ui = True
                for name in list_files(root, "" if rel == "." else rel):
                    targets[name] = None
            else:
                print("見つかりません: " + given, file=sys.stderr)
    else:
        for name in list_files(root, ""):
            targets[name] = None

    if args.base:
        try:
            changes = changed_lines(root, args.base)
        except RuntimeError as error:
            sys.exit(str(error))
        if args.paths:
            targets = {name: changes[name] for name in targets if name in changes}
        else:
            targets = changes

    patterns = EXCLUDES + args.exclude + ([] if include_ui else UI_DIRS)
    findings, scanned = [], 0
    for name in sorted(targets):
        ext = os.path.splitext(name)[1].lower()
        if ext not in MARKUP | STYLE:
            continue
        if name not in explicit and excluded(name.replace(os.sep, "/"), patterns):
            continue
        lines_filter = targets[name]
        if lines_filter is not None and not lines_filter:
            continue
        if scan_file(os.path.join(base_dir, name), name, lines_filter, findings):
            scanned += 1

    findings.sort(key=lambda f: (f[0], f[1], CATEGORIES.index(f[2])))
    if not findings:
        print("候補なし（%d ファイルを確認）" % scanned)
        return

    def breakdown(counter):
        return " / ".join("%s %d" % (cat, counter[cat]) for cat in CATEGORIES if counter[cat])

    counts = Counter(cat for _, _, cat, _, _ in findings)
    print("候補 %d 件（%d ファイルを確認）: %s" % (len(findings), scanned, breakdown(counts)))
    print()

    if args.summary:
        per_file = {}
        for name, _, cat, _, _ in findings:
            per_file.setdefault(name, Counter())[cat] += 1
        rows = sorted(per_file.items(), key=lambda row: (-sum(row[1].values()), row[0]))
        for name, counter in rows[:args.limit]:
            print("%4d  %s — %s" % (sum(counter.values()), name, breakdown(counter)))
        if len(rows) > args.limit:
            print("… ほか %d ファイル（--limit で増やせる）" % (len(rows) - args.limit))
        return

    for path, number, cat, name, text in findings[:args.limit]:
        print("%s:%d [%s] %s — %s" % (path, number, cat, name, text))
    if len(findings) > args.limit:
        print("… ほか %d 件（--limit で増やせる）" % (len(findings) - args.limit))

    print()
    print("見方（* は文脈次第。直すかどうかは周りを見て決める）:")
    seen = []
    for _, _, _, name, _ in findings:
        if name not in seen:
            seen.append(name)
    for name in seen:
        weak, hint = HINTS[name]
        print("- %s%s: %s" % (name, " *" if weak else "", hint))


if __name__ == "__main__":
    main()
