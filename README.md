# yuya-claude-code

自分用の Claude Code プラグインマーケットプレイスです。

実戦投入されている agents, skills, rules, hooks をベースにしています。

---

## 構成

```text
yuya-claude-code/            # マーケットプレイス (このリポジトリ)
├── .claude-plugin/
│   └── marketplace.json     # マーケットプレイスカタログ
├── my-claude-code/          # プラグイン本体
│   ├── .claude-plugin/
│   │   └── plugin.json      # プラグインマニフェスト
│   ├── agents/              # 専門エージェント (10種)
│   ├── skills/              # ワークフロー (20種)
│   ├── hooks/               # 自動フォーマット (hooks.json + format-file.sh)
│   ├── rules/               # 常時適用ガイドライン (9種) ※ /setup で展開
│   └── templates/
│       └── settings.json    # permissions テンプレート ※ /setup で展開
└── mcp/                     # 将来追加する MCP サーバー用 (mcp/README.md 参照)
```

---

## 前提条件

- リモート連携 CLI がインストール・認証済みであること（リモート URL から自動判定されます）
  - **GitLab**: [`glab` CLI](https://gitlab.com/gitlab-org/cli)
  - **GitHub**: [`gh` CLI](https://cli.github.com/)
- **develop** ブランチをデフォルトブランチとして運用していること（違う場合は `/my-claude-code:init` で調整）

> CLI が未導入の場合、`/my-claude-code:mr`, `/my-claude-code:issue-create`, `/my-claude-code:dev-wt`, `/my-claude-code:dev-bc`, `/my-claude-code:slack-issue` 等のリモート連携スキルが動作しません。

---

## セットアップ

### 1. プラグインのインストール (agents / skills / hooks)

Claude Code 内で以下を実行:

```shell
/plugin marketplace add yuya-take/yuya-claude-code
/plugin install my-claude-code@yuya-claude-code
```

スキルは `my-claude-code` でネームスペース化されます (例: `/my-claude-code:code-review`)。

更新は `/plugin marketplace update yuya-claude-code` → `/plugin update my-claude-code@yuya-claude-code`、または自動更新に任せます。

### 2. rules / settings の展開

`rules/`（常時適用ガイドライン）と `settings.json`（permissions）はプラグインの仕組みでは自動ロードされないため、プラグインに同梱したものを `setup` スキルでプロジェクトの `.claude/` に展開します。対象プロジェクトで:

```shell
/my-claude-code:setup
```

> - **既存ファイルは上書きしません**（差分がある場合は確認してから）
> - **`settings.json`** は permissions.allow のみマージされます
> - プラグイン更新で rules が変わった時も再実行すれば追従できます

### 3. プロジェクトに合わせてカスタマイズ

対象プロジェクトで Claude Code を起動し、`/my-claude-code:init` を実行してください。

プロジェクトの構造を自動解析し、以下を行います:

- 環境チェック（GitLab / GitHub の判定、`glab` / `gh` CLI、`develop` ブランチの確認）
- 設定ファイル内の例をプロジェクトの実際のパスに置換
- `settings.json` の permissions をプロジェクトに合わせて調整
- `rules/` の `paths:` をプロジェクトのディレクトリ構成に更新
- `test-runner` のテストコマンドを実際の構成に更新

プロジェクト構成が変わった時も再実行すれば更新できます。

---

## 主要な設定

### Agents (10 種)

| Agent | 用途 |
|-------|------|
| `code-reviewer` | Clean Architecture 準拠・命名規則・型安全性チェック |
| `python-reviewer` | Python コード品質レビュー |
| `rust-reviewer` | Rust コード品質レビュー |
| `security-reviewer` | セキュリティ脆弱性チェック |
| `database-reviewer` | DB スキーマ・クエリレビュー |
| `api-spec-reviewer` | API 仕様レビュー |
| `clean-arch-guard` | Clean Architecture 違反検出 |
| `migration-checker` | マイグレーション安全性チェック |
| `refactor-cleaner` | リファクタリング支援 |
| `test-runner` | テスト実行・結果分析 |

### Skills (20 種)

呼び出しは `/my-claude-code:<skill名>`。

| Skill | 用途 |
|-------|------|
| `setup` | rules / settings をプロジェクトの `.claude/` に展開 |
| `code-review` | 未コミット変更のレビュー |
| `code-review-full` | 包括的コードレビュー |
| `code-review-est` | 指定フォルダの既存コード全体レビュー |
| `review-mr` | 指定した既存 MR/PR をレビューし承認後にコメント投稿 |
| `mr` | Merge Request / Pull Request 作成 |
| `dev-wt` | Issue 駆動 Worktree 開発 |
| `dev-bc` | ブランチベース開発 |
| `explain` | コード解説 |
| `issue-create` | Issue 作成 |
| `issue-refine` | Issue の曖昧な内容をコード解析+対話で詳細化 |
| `refactor-clean` | リファクタリング |
| `python-review` | Python 専用レビュー |
| `rust-review` | Rust 専用レビュー |
| `security-review` | セキュリティレビュー |
| `skill-create` | 新規スキル作成 |
| `slack-issue` | Slack → Issue 連携 |
| `troubleshooting` | トラブルシューティング |
| `init` | プロジェクト初期化・設定カスタマイズ |
| `sync` | develop ブランチの最新取得 |

### Rules (9 種)

Clean Architecture, 命名規則, Git ワークフロー, Python/Rust/フロントエンド標準, DB, Orval, エージェント利用ルール

### Hooks

- `PostToolUse (Edit|Write)` → 自動フォーマット実行（プラグインに同梱、インストールするだけで有効）

---

## 使い分けガイド

**まず試すならこの 3 つ:**

1. `/my-claude-code:code-review` — 日常的なコードレビュー
2. `/my-claude-code:mr` — MR 作成の自動化
3. `/my-claude-code:dev-wt` — Issue から Worktree を切って開発

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
