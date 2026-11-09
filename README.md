# yuya-claude-code

自分用の Claude Code 設定集です。`gh` コマンドのワンライナーで各プロジェクトの `.claude/` に展開して使います。

実戦投入されている agents, skills, rules, hooks をベースにしています。

---

## 構成

```text
yuya-claude-code/            # このリポジトリ
├── install.sh               # ワンライナー展開用スクリプト
├── .claude-plugin/
│   └── marketplace.json     # マーケットプレイスカタログ (プラグイン方式用)
├── my-claude-code/          # 配布物本体 (プラグインとしても機能)
│   ├── .claude-plugin/
│   │   └── plugin.json      # プラグインマニフェスト
│   ├── agents/              # 専門エージェント (9種)
│   ├── skills/              # ワークフロー (12種)
│   ├── hooks/               # 自動フォーマット (hooks.json + format-file.sh)
│   ├── rules/               # 常時適用ガイドライン (9種)
│   └── templates/
│       └── settings.json    # permissions テンプレート
└── mcp/                     # 将来追加する MCP サーバー用 (mcp/README.md 参照)
```

---

## 前提条件

- リポジトリが **GitHub** でホストされていること
- [`gh` CLI](https://cli.github.com/) がインストール・認証済み（`gh auth login`）であること
- **develop** ブランチをデフォルトブランチとして運用していること（違う場合は `/setup` で調整）

> `gh` が未導入の場合、`/pr`, `/rv`（PR モード）, `/issue-create`, `/dev`, `/slack-issue` 等のリモート連携スキルが動作しません。

---

## セットアップ

### 1. ワンライナーで展開 (agents / skills / rules / hooks / settings)

対象プロジェクトのルートで実行:

```bash
curl -fsSL https://raw.githubusercontent.com/yuya-take/yuya-claude-code/main/install.sh | bash
```

`.claude/` 配下に agents / skills / rules / hooks が展開され、`settings.json` に permissions と自動フォーマット hook がマージされます。

> - **既存ファイルは上書きしません**（内容が異なるファイルはスキップして一覧表示）
> - 上書きしたい場合は末尾に `| bash -s -- --force` を付けて実行
> - 旧バージョンの廃止スキル・agent（`dev-wt`, `code-review`, `clean-arch-guard` など）は `| bash -s -- --prune` で削除（`--force` にも含まれる）
> - **`settings.json`** は permissions.allow の和集合 + hook の追記のみで、既存の設定は消しません
> - 更新時も同じコマンドを再実行するだけで追従できます

スキルの呼び出しは `/<skill名>` です (例: `/rv`)。

<details>
<summary>別の方法: プラグインとしてインストール</summary>

Claude Code 内で以下を実行:

```shell
/plugin marketplace add yuya-take/yuya-claude-code
/plugin install my-claude-code@yuya-claude-code
```

スキルは `my-claude-code` でネームスペース化されます (例: `/my-claude-code:rv`)。
rules と settings はプラグインの仕組みでは自動ロードされないため、続けて `/my-claude-code:setup` を実行してください（展開とカスタマイズをまとめて行います）。

更新は `/plugin marketplace update yuya-claude-code` → `/plugin update my-claude-code@yuya-claude-code`。

</details>

### 2. プロジェクトに合わせてカスタマイズ

対象プロジェクトで Claude Code を起動し、`/setup` を実行してください。

プロジェクトの構造を自動解析し、以下を行います:

- 環境チェック（GitHub リモート、`gh` CLI の導入・認証、`develop` ブランチの確認）
- 設定ファイル内の例をプロジェクトの実際のパスに置換
- `settings.json` の permissions をプロジェクトに合わせて調整
- `rules/` の `paths:` をプロジェクトのディレクトリ構成に更新
- `test-runner` のテストコマンドを実際の構成に更新

プロジェクト構成が変わった時も再実行すれば更新できます。

---

## 主要な設定

### Agents (9 種)

レビュー系は `/rv` が変更内容に応じて自動で振り分けます。レビュー系は `opus`、`test-runner` は `sonnet` で動きます。各 reviewer は確信度付きで指摘を網羅的に返し、絞り込みは `/rv` がまとめて行います（Opus 4.7 以降は「重要なものだけ報告」と指示すると見落としが増えるため）。

| Agent | 用途 |
|-------|------|
| `code-reviewer` | 正しさ・変更スコープ・規約の横断レビュー（他に該当がない変更のフォールバック） |
| `python-reviewer` | Python コード品質・Clean Architecture のレイヤー違反 |
| `rust-reviewer` | Rust コード品質レビュー |
| `frontend-reviewer` | TypeScript / React コード品質レビュー |
| `security-reviewer` | セキュリティ脆弱性チェック |
| `database-reviewer` | DB スキーマ・クエリ・マイグレーションの内容と反映漏れ |
| `api-spec-reviewer` | API 仕様レビュー |
| `refactor-cleaner` | デッドコード・重複の検出 |
| `test-runner` | テスト実行・失敗分析（指示したときだけ使う） |

### Skills (12 種)

呼び出しは `/<skill名>`（プラグインとしてインストールした場合は `/my-claude-code:<skill名>`）。
Claude Code 組み込みの `/init`, `/review`, `/code-review`, `/security-review` と名前が衝突しないようにしています。

| Skill | 用途 |
|-------|------|
| `dev` | Issue / タスクから設計→実装→検証→セルフレビューまで。既定は Worktree、`--branch` でブランチ開発 |
| `rv` | 統合レビュー。ブランチ差分 / `--staged` / PR / フォルダ監査を自動判別し、変更内容に応じて reviewer を振り分け |
| `pr` | コミット分割 → プッシュ → PR 作成/更新 |
| `sync` | ベースブランチの最新化と Worktree の片付け |
| `setup` | rules / settings の展開とプロジェクトに合わせたカスタマイズ |
| `issue-create` | Issue 作成 |
| `issue-refine` | Issue の曖昧な内容をコード解析+対話で詳細化 |
| `slack-issue` | Slack → Issue 連携 |
| `explain` | コード解説 |
| `refactor-clean` | デッドコード削除 |
| `skill-create` | 新規スキル作成 |
| `troubleshooting` | トラブルシューティング |

#### `/dev`

```text
/dev #123                 # Worktree で隔離開発（既定）
/dev #123 --branch        # カレントリポジトリでブランチを切って開発
/dev "CSV出力を追加"       # Issue なしでも可
/dev #123 --base feat/epic # 分岐元を指定（既定は develop）
/dev #123 --quick         # Plan モードを省略（小さな修正向け）
```

#### `/rv`

```text
/rv                       # ブランチ差分（分岐点から + 未コミット分）
/rv --staged              # ステージ済みのみ
/rv #45                   # PR をレビューし、承認後にコメント投稿
/rv backend/app/domain/   # 既存コードの監査
/rv --deep                # 規模に関係なく全 reviewer を起動
/rv --fix                 # CRITICAL/HIGH を修正して再検証
```

変更ファイルを分類して必要な reviewer だけを並列起動し（小さな差分ではサブエージェントを使わず 1 パス）、CRITICAL/HIGH はコードを読み直して裏取りしてから報告します。

### Rules (9 種)

Clean Architecture, 命名規則, Git ワークフロー, Python/Rust/フロントエンド標準, DB, Orval, エージェント利用ルール

### Hooks

- `PostToolUse (Edit|Write)` → 自動フォーマット実行（ワンライナー展開時は `.claude/settings.json` に登録され、`.claude/hooks/format-file.sh` が実行されます）

---

## 使い分けガイド

**まず試すならこの 3 つ:**

1. `/dev #123` — Issue から開発（Worktree）
2. `/rv` — 変更内容に合わせたレビュー
3. `/pr` — PR 作成の自動化

---

## MCP サーバーの追加

将来の MCP サーバーは `mcp/` 配下に 1 サーバー = 1 プラグインで追加し、`.claude-plugin/marketplace.json` にエントリを足します。手順は [mcp/README.md](mcp/README.md) を参照してください。

---

## マーケットプレイスの検証

変更をコミットする前に:

```bash
claude plugin validate .
```

---

## 貢献

[CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。
