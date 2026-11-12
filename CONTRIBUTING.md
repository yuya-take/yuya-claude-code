# yuya-claude-code への貢献

このリポジトリは Claude Code のプラグインマーケットプレイスです。

---

## 貢献の流れ

### 1. ブランチを作成

```bash
git switch -c feat/your-feature-name
```

### 2. ファイルを追加・編集

配布物は `packs/<pack>/` に置きます。1 つの pack が 1 つのプラグインになり、install.sh も同じディレクトリから展開します。

- `packs/<pack>/skills/<name>/SKILL.md` — スキル
- `packs/<pack>/agents/` — サブエージェント定義
- `packs/<pack>/rules/` — 利用先の `.claude/rules/` に展開する rule（プラグイン方式では `/setup` が展開する）
- `packs/<pack>/hooks/` — `hooks.json` とフックスクリプト。コマンドは `${CLAUDE_PLUGIN_ROOT}/hooks/...` で書く（install.sh が `.claude/hooks/` を指す形に書き換えて登録する）
- `packs/<pack>/project-settings.json` — 利用先の `.claude/settings.json` にマージする permissions など。プラグイン直下の `settings.json` は別の意味（プラグインの既定設定）を持つので、この名前にしている
- `packs/<pack>/.claude-plugin/plugin.json` — pack の説明と、依存する pack（`dependencies`）
- `mcp/` — MCP サーバープラグイン（[mcp/README.md](mcp/README.md) 参照）

どの pack に置くかは、「その pack だけ入れた利用者に必要か」で決めます。スキルが別の pack のファイルを参照する場合は、依存（`dependencies`）を宣言してください。

新しい pack を作る場合は、`packs/<pack>/.claude-plugin/plugin.json` を作り、ルートの `.claude-plugin/marketplace.json` にエントリを追加し（並び順が install.sh の表示順になる）、`bundles/all` の `dependencies` と README の pack 一覧にも追加してください。

### 3. 検証・テスト

```bash
claude plugin validate .
```

install.sh は、一時ディレクトリで実行して確認します（このリポジトリのクローンから実行すると、ローカルの `packs/` を使います）:

```bash
mkdir -p /tmp/try && cd /tmp/try && touch pyproject.toml
bash /path/to/yuya-claude-code/install.sh --list
bash /path/to/yuya-claude-code/install.sh
```

プラグインとしての動作は、ローカルの marketplace として追加して確認します:

```shell
/plugin marketplace add ./path/to/yuya-claude-code
/plugin install dev-flow@yuya-claude-code
```

### 4. PR を作成

```bash
git add .
git commit -m "feat: 機能の説明"
git push -u origin feat/your-feature-name
```

---

## ファイル形式

### Agents

```markdown
---
name: agent-name
description: 説明
tools: Read, Grep, Glob
model: sonnet
---

指示内容...
```

### Skills

`packs/<pack>/skills/<skill-name>/SKILL.md` に配置：

```markdown
---
name: skill-name
description: 説明
---

指示内容...
```

### Rules

```markdown
# ルール名

ガイドライン内容...
```

---

## このリポジトリでの開発

このリポジトリの `.claude/` には、配布物から開発に必要なものを symlink で置いている。配布物を直すと、このリポジトリでの動作にもそのまま反映される。

| 種類 | 置いているもの |
|---|---|
| skills | `dev`, `orchestrate`, `pr`, `sync`（`packs/dev-flow/skills/` への symlink）、`rv`（`packs/review/skills/` への symlink） |
| agents | `code-reviewer`, `security-reviewer`（`packs/review/agents/` への symlink） |
| このリポジトリ専用 | `model-tune` — 新しいモデルや Claude Code の仕様変更に合わせて配布物を点検・修正する |

新しい Claude モデルが出たときや、Claude Code のスキル・agent・settings の仕様が変わったときは `/model-tune` を実行する。点検の記録は `.claude/skills/model-tune/history.md` に残る。

---

## 変更時の作業

- コミットするだけで配布される（プラグインのバージョンは git コミット SHA ベース）
- install.sh の利用者は同じコマンドの再実行で、プラグインの利用者は `/plugin update` と `/core:setup` の再実行で追従する

---

## ガイドライン

- 設定はシンプルに保つ
- 説明を含める
- 提出前にテストする
- 既存のパターンに従う
- API キーなどの機密情報を含めない
- 実プロジェクトで動作確認済みのものを優先
- スキル名は Claude Code の組み込みコマンド（`/init`, `/review`, `/code-review`, `/security-review` など）と被らせない
- `disable-model-invocation: true` は、ユーザーが自分で始めるスキルにだけ付ける。他のスキルや rule の手順でモデルに呼ばせるスキル（`/pr`、`/rv` など）には付けない（付けるとモデルが Skill ツールで呼べず、手順を手で再現することになる）
- レビュー系 agent は `review` pack に置く（`/rv` と `/dev` が定義ファイルを同じ pack から読むため）。`packs/review/rules/agents.md` の統一出力フォーマットに従い、`/rv` の振り分け表にも追加する
- スキル・agent・フックを廃止・改名した場合は、`install.sh` の `DEPRECATED` に旧パスを追加する（導入記録の無い旧バージョンの利用者が `--prune` で片付けられるように）。導入記録のある利用者には、記録から自動で検出される
