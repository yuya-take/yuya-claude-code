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
│   ├── agents/              # 専門エージェント (10種)
│   ├── skills/              # ワークフロー (20種)
│   ├── hooks/               # 自動フォーマット (hooks.json + format-file.sh)
│   ├── rules/               # 常時適用ガイドライン (9種)
│   └── templates/
│       └── settings.json    # permissions テンプレート
└── mcp/                     # 将来追加する MCP サーバー用 (mcp/README.md 参照)
```

---

## 前提条件

- リモート連携 CLI がインストール・認証済みであること（リモート URL から自動判定されます）
  - **GitLab**: [`glab` CLI](https://gitlab.com/gitlab-org/cli)
  - **GitHub**: [`gh` CLI](https://cli.github.com/)
- **develop** ブランチをデフォルトブランチとして運用していること（違う場合は `/init` で調整）

> CLI が未導入の場合、`/mr`, `/issue-create`, `/dev-wt`, `/dev-bc`, `/slack-issue` 等のリモート連携スキルが動作しません。

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
> - **`settings.json`** は permissions.allow の和集合 + hook の追記のみで、既存の設定は消しません
> - 更新時も同じコマンドを再実行するだけで追従できます

スキルの呼び出しは `/<skill名>` です (例: `/code-review`)。

<details>
<summary>別の方法: プラグインとしてインストール</summary>

Claude Code 内で以下を実行:

```shell
/plugin marketplace add yuya-take/yuya-claude-code
/plugin install my-claude-code@yuya-claude-code
```

スキルは `my-claude-code` でネームスペース化されます (例: `/my-claude-code:code-review`)。
rules と settings はプラグインの仕組みでは自動ロードされないため、続けて `/my-claude-code:setup` で展開してください。

更新は `/plugin marketplace update yuya-claude-code` → `/plugin update my-claude-code@yuya-claude-code`。

</details>

### 2. プロジェクトに合わせてカスタマイズ

対象プロジェクトで Claude Code を起動し、`/init` を実行してください。

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

呼び出しは `/<skill名>`（プラグインとしてインストールした場合は `/my-claude-code:<skill名>`）。

| Skill | 用途 |
|-------|------|
| `setup` | rules / settings を `.claude/` に展開（プラグイン方式専用。ワンライナー展開では不要のため除外） |
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

- `PostToolUse (Edit|Write)` → 自動フォーマット実行（ワンライナー展開時は `.claude/settings.json` に登録され、`.claude/hooks/format-file.sh` が実行されます）

---

## 使い分けガイド

**まず試すならこの 3 つ:**

1. `/code-review` — 日常的なコードレビュー
2. `/mr` — MR 作成の自動化
3. `/dev-wt` — Issue から Worktree を切って開発

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
