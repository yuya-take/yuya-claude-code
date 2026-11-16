# yuya-claude-code への貢献

このリポジトリは Claude Code のプラグインマーケットプレイスです。

## 貢献の流れ

不具合の報告や提案は Issue で、変更は PR で受け付けています。大きな変更は、先に Issue で相談してください。

送られた変更は、このリポジトリと同じ [MIT License](LICENSE) で公開されます。

### 1. フォークしてブランチを作成

このリポジトリに直接 push できるのはメンテナだけです。GitHub でフォークし、フォーク側でブランチを切ってください。

```bash
gh repo fork yuya-take/yuya-claude-code --clone
cd yuya-claude-code
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

新しい pack を作る場合は、`packs/<pack>/.claude-plugin/plugin.json` を作り、ルートの `.claude-plugin/marketplace.json` にエントリを追加し（並び順が install.sh の表示順になる）、`bundles/all` の `dependencies` と README の pack の表にも追加してください。スキルを追加・改名・廃止した場合は、README のスキルの表も直してください。

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

コミットメッセージは `<type>: <説明>`（例: `feat: 〇〇 スキルを追加`）。フォークに push し、このリポジトリの `main` に向けて PR を出します。

```bash
git add .
git commit -m "feat: 機能の説明"
git push -u origin feat/your-feature-name
gh pr create --repo yuya-take/yuya-claude-code --base main
```

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

## このリポジトリでの開発

このリポジトリの `.claude/` には、配布物のうち開発に必要なものを symlink で置いています。配布物を直すと、このリポジトリでの動作にもそのまま反映されます。

| 種類 | 置いているもの |
|---|---|
| skills | `dev`, `orchestrate`, `pr`, `sync`（`packs/dev-flow/skills/` への symlink）、`rv`（`packs/review/skills/` への symlink） |
| agents | `code-reviewer`, `security-reviewer`（`packs/review/agents/` への symlink） |
| このリポジトリ専用 | `model-tune` — 新しいモデルや Claude Code の仕様変更に合わせて配布物を点検・修正する |

新しい Claude モデルが出たときや、Claude Code のスキル・agent・settings の仕様が変わったときは、`/model-tune` を実行します。点検の記録は `.claude/skills/model-tune/history.md` に残ります。

## 変更の配布

`main` にマージするだけで配布されます（プラグインのバージョンは git のコミット SHA で決まります）。利用者は次の方法で追従します。
- install.sh の利用者: 同じコマンドを再実行する
- プラグインの利用者: `/plugin update` の後に `/core:setup` を再実行する

## リポジトリ構成

```text
yuya-claude-code/
├── install.sh                 # pack を .claude/ に展開するスクリプト
├── .claude-plugin/
│   └── marketplace.json       # marketplace カタログ（pack ごとのプラグインと bundle を列挙）
├── packs/
│   └── <pack>/                # 1 pack = 1 プラグイン
│       ├── .claude-plugin/
│       │   └── plugin.json    # 説明と依存する pack（install.sh もこれを読む）
│       ├── skills/ agents/ rules/
│       ├── hooks/             # hooks.json とフックスクリプト
│       └── project-settings.json  # 利用先の settings.json にマージする permissions など
├── bundles/
│   └── all/                   # 全 pack に依存するだけの bundle プラグイン
├── mcp/                       # MCP サーバーのプラグイン用（今は空。追加手順は mcp/README.md）
└── .claude/                   # このリポジトリ自身の開発用（packs/ への symlink と /model-tune）
```

## ガイドライン

- 配布物の文面は、利用先のプロジェクトで読まれる前提で書く。このリポジトリ固有の事情は書かない
- 既存のスキルや rule の書き方に揃える
- API キーなどの機密情報を含めない
- 実際のプロジェクトで動作を確かめたものを優先する
- スキル名は Claude Code の組み込みコマンド（`/init`, `/review`, `/code-review`, `/security-review` など）と被らせない
- `disable-model-invocation: true` は、ユーザーが自分で始めるスキルにだけ付ける。他のスキルや rule の手順でモデルに呼ばせるスキル（`/pr`、`/rv` など）には付けない（付けるとモデルが Skill ツールで呼べず、手順を手で再現することになる）
- レビュー系 agent は `review` pack に置く（`/rv` と `/dev` が定義ファイルを同じ pack から読むため）。`packs/review/rules/agents.md` の統一出力フォーマットに従い、`/rv` の振り分け表にも追加する
- スキル・agent・フックを廃止・改名した場合は、`install.sh` の `DEPRECATED` に旧パスを追加する（導入記録の無い旧バージョンの利用者が `--prune` で片付けられるように）。導入記録のある利用者には、記録から自動で検出される
