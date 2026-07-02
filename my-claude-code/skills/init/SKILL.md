---
name: init
description: プロジェクトの .claude/ 設定を解析・カスタマイズする。初回セットアップや構成変更時に /init で実行。
---

# プロジェクト初期化・更新

このスキルは、`/my-claude-code:setup` で `.claude/` に展開した rules / settings をプロジェクトに合わせてカスタマイズする。
初回セットアップ時だけでなく、プロジェクト構成が変わった時にも再実行できる。
`.claude/rules/` が無い場合は、先に `/my-claude-code:setup` の実行を案内すること。

## 手順

### Step 1: 環境チェック

以下を確認し、問題があればユーザーに警告する:

1. **ホスティング判定**: `git remote get-url origin` で GitLab / GitHub を判定する:
   - `github.com` を含む → **GitHub**（`gh` を使用、MR は PR と読み替え）
   - それ以外（GitLab セルフホスト含む） → **GitLab**（`glab` を使用）
   - リモートが無い場合は「リモートリポジトリが設定されていません。リモート連携スキル（mr, issue-create 等）は動作しません」と警告

2. **CLI**: 判定したプラットフォームの CLI を `which glab` / `which gh` で存在確認。未インストールの場合:
   - GitLab: 「`glab` がインストールされていません: https://gitlab.com/gitlab-org/cli」と警告
   - GitHub: 「`gh` がインストールされていません: https://cli.github.com/」と警告
   - skills/mr, skills/issue-create, skills/dev-wt, skills/dev-bc 等が動作しません

3. **develop ブランチ**: `git branch -a` で develop が存在するか確認。存在しない場合:
   - 「`develop` ブランチが見つかりません。このテンプレートは develop ブランチを前提としています」と警告
   - `rules/git-workflow.md` のブランチ戦略をプロジェクトに合わせて修正してください

すべてのチェックが通過した場合も、結果をユーザーに報告してから次のステップに進む。

### Step 2: プロジェクト構造の解析

現在のプロジェクトの構造を調査する:

1. **リポジトリルート**のディレクトリ構成を確認 (`ls`, `find`)
2. **言語・フレームワーク**を特定:
   - `pyproject.toml`, `Makefile` → Python (ruff, pytest)
   - `package.json`, `biome.json` → Frontend (biome, npm)
   - `Cargo.toml` → Rust (cargo)
   - `orval.config.ts` → Orval API生成あり
3. **サービス構成**を特定:
   - モノレポの場合、各サービスディレクトリを列挙
   - バックエンド/フロントエンドの分離パターンを把握
4. **テストコマンド**を特定:
   - `Makefile` の test ターゲット
   - `package.json` の test スクリプト
   - `Cargo.toml` のテスト設定
5. **マイグレーション**の場所を特定:
   - `alembic/`, `migrations/` 等のディレクトリ
   - モデル定義の場所
6. **ログライブラリ**を特定:
   - `structlog`, `logging`, `tracing` 等の使用状況

### Step 3: ユーザーに確認

解析結果をユーザーに提示し、以下を確認する:

```
## プロジェクト解析結果

- プロジェクト名: {{project_name}}
- 言語: Python / TypeScript / Rust
- サービス構成:
  - {{service_1}}: {{path_1}}
  - {{service_2}}: {{path_2}}
- テストコマンド:
  - Backend: {{test_cmd}}
  - Frontend: {{test_cmd}}
- ログライブラリ: {{log_lib}}
- Orval: あり / なし

この内容で設定を更新しますか？
```

### Step 4: プレースホルダーの置換

ユーザーの承認後、`.claude/` 配下のファイル内の例示やサンプルパスをプロジェクトの実態に合わせて更新する。

具体的には:
- サンプルパス（例: `app/presentation/route/`）→ プロジェクトの実際のパス
- サンプルコマンド（例: `make lint`）→ プロジェクトの実際のコマンド
- サンプル設定 → プロジェクトの実際の設定値

**置換方法**: 各ファイルを Read → Edit で更新する。`sed` は使わない。

### Step 5: rules の paths 更新

`rules/*.md` の frontmatter にある `paths:` フィールドを、プロジェクトの実際のディレクトリ構成に合わせて更新する。

対象ファイルと更新内容:

| ファイル | デフォルト paths | 更新例 |
|---------|-----------------|--------|
| `clean-architecture.md` | `**/backend/**/*.py` | プロジェクトの Python バックエンドパス |
| `database.md` | `**/migrations/**`, `**/adapter/model/**/*.py` | マイグレーション・モデルの実パス |
| `frontend-standards.md` | `**/frontend/**/*.{ts,tsx,js,jsx}` | フロントエンドの実パス |
| `naming-conventions.md` | `**/*.py` | 対象言語に応じて調整 |
| `orval.md` | `frontend/**/*.{ts,tsx}` 等 | Orval 生成先の実パス |
| `python-standards.md` | `**/*.py` | そのままで OK な場合が多い |
| `rust-standards.md` | `**/*.rs` | そのままで OK な場合が多い |

`paths:` が無い rules (`agents.md`, `git-workflow.md`) は常時適用のため変更不要。

### Step 6: settings.json の更新

`.claude/settings.json` の permissions を、プロジェクトで実際に使うコマンドだけに絞る:

- Python プロジェクト: `make lint`（または実際の lint ターゲット名）, `make test`, `uv run pytest`, `uv run ruff` を残す
- Frontend プロジェクト: `npm run biome`, `npm run build`, `npm test` を残す
- 使わないツールの permission は削除

### Step 7: test-runner の更新

`agents/test-runner.md` のテストコマンドテーブルを、実際のサービス構成に合わせて更新する。

### Step 8: 完了報告

更新したファイル一覧を報告する。

## 再実行時の注意

- 既にカスタマイズ済みのファイルは上書きしない
- 新しいサービスが追加された場合は、該当箇所のみ追加更新する
- ユーザーが手動で編集した内容を尊重する (diff を確認してから更新)
