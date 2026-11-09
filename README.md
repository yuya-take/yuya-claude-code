# yuya-claude-code

自分用の Claude Code 設定集です。用途ごとの **pack** に分かれていて、プロジェクトに必要な pack だけを `.claude/` に展開して使います。

実戦投入されている agents, skills, rules, hooks をベースにしています。

---

## pack

| pack | 中身 | 依存 |
|------|------|------|
| `core` | `/setup`（展開とプロジェクトに合わせた調整）、`/explain`、`/skill-create`（git 履歴からスキル生成）、Git ワークフローの rule、基本の permissions | — |
| `review` | `/rv`（統合レビュー）、`/refactor-clean`、reviewer agent 一式、agents rule | core |
| `dev-flow` | `/issue-create`・`/issue-refine`（Issue の作成と詳細化）、`/dev`（Issue から設計・実装・セルフレビュー）、`/pr`、`/sync` | core, review |
| `python` | Python / 命名 / Clean Architecture / DB の rules、`/troubleshooting`（サービス起動・DB・マイグレーションの対処）、ruff の自動フォーマット、uv・pytest の permissions | core |
| `frontend` | TypeScript / React / Orval の rules、biome の自動フォーマット、npm の permissions | core |
| `rust` | Rust の rules、cargo の permissions | core |

依存する pack は自動で一緒に入ります。reviewer agent は言語に関係なくすべて `review` に入っています。`/rv` は変更されたファイルの種類に合う reviewer だけを起動するので、使わない言語の reviewer が動くことはありません。

---

## 前提条件

- リポジトリが **GitHub** でホストされていること
- [`gh` CLI](https://cli.github.com/) がインストール・認証済み（`gh auth login`）であること
- `python3` と `git` があること（install.sh が使います）

ベースブランチは `develop` があればそれを、無ければリモートのデフォルトブランチ（`main` など）を使います。

---

## セットアップ

### 1. pack を展開する

対象プロジェクトのルートで実行します。

```bash
curl -fsSL https://raw.githubusercontent.com/yuya-take/yuya-claude-code/main/install.sh | bash
```

`--packs` を指定しない初回は、`core`・`review`・`dev-flow` と、プロジェクトのファイルから検出した言語の pack を入れます。検出に使うファイルは、`pyproject.toml` / `requirements.txt` が python、`package.json` が frontend、`Cargo.toml` が rust です。2 回目以降は前回と同じ pack を使います。

```bash
# 入れる pack を指定する（依存する pack は自動で追加）
curl -fsSL .../install.sh | bash -s -- --packs dev-flow,python,rust

# 全部入れる
curl -fsSL .../install.sh | bash -s -- --packs all

# pack の一覧と、このプロジェクトでの選択を表示する
curl -fsSL .../install.sh | bash -s -- --list
```

`.claude/` には skills / agents / rules / hooks が展開されます。`.claude/settings.json` には、選んだ pack の permissions と自動フォーマットの hook がマージされます。

- **更新:** 同じコマンドを再実行します。手元で変更していないファイルは、配布元の最新版に更新されます。
- **手元で変更したファイル:** 上書きせず、スキップして一覧に出します。上書きするには `--force` を付けます。
- **不要になったファイル:** pack を外したときや、廃止したスキル・agent が残っているときは、一覧に出します。`--prune`（`--force` にも含まれる）で削除します。削除するのは、このスクリプトが入れたもので、かつ手元で変更していないファイルだけです。
- **`settings.json`:** permissions の追加と hook の登録だけを行い、既存の設定は消しません。
- **導入記録:** 入れた pack とファイルは `.claude/.yuya-claude-code.json` に記録されます。チームで共有する場合は、`.claude/` ごとコミットしてください。

スキルの呼び出しは `/<skill名>` です（例: `/rv`）。

<details>
<summary>別の方法: プラグインとしてインストール</summary>

Claude Code 内で、marketplace を追加してから必要な pack を入れます。依存する pack は自動で入ります。

```shell
/plugin marketplace add yuya-take/yuya-claude-code
/plugin install dev-flow@yuya-claude-code
/plugin install python@yuya-claude-code
# 全部入れる場合
/plugin install all@yuya-claude-code
```

スキルは pack 名で名前空間化されます（例: `/dev-flow:dev`, `/review:rv`, `/core:setup`）。

rules と permissions はプラグインの仕組みでは配布されないため、続けて `/core:setup` を実行してください。入れた pack の rules と permissions の展開、プロジェクトに合わせた調整までまとめて行います。

更新は `/plugin marketplace update yuya-claude-code` の後、各 pack を `/plugin update` してください。

</details>

### 2. プロジェクトに合わせてカスタマイズ

対象プロジェクトで Claude Code を起動し、`/setup` を実行してください。

プロジェクトの構造を解析し、次を行います。

- 環境チェック（GitHub リモート、`gh` CLI の導入・認証、ベースブランチ、Worktree 用の `.gitignore`）
- rules の `paths:` と例示を、プロジェクトの実際のディレクトリやコマンドに合わせる
- `settings.json` の permissions を、プロジェクトで使うコマンドに合わせる
- `/rv` の振り分け表や `test-runner` のテストコマンドを、実際の構成に合わせる

プロジェクトの構成が変わったときも、再実行すれば更新できます。

---

## 主なスキル

**まず試すならこの 3 つ:**

1. `/dev #123` — Issue から開発（Worktree）
2. `/rv` — 変更内容に合わせたレビュー
3. `/pr` — PR 作成の自動化

#### `/dev`（dev-flow）

```text
/dev #123                  # Worktree で隔離開発（既定）
/dev #123 --branch         # カレントリポジトリでブランチを切って開発
/dev "CSV出力を追加"        # Issue なしでも可
/dev #123 --base feat/epic # 分岐元を指定（既定は develop、無ければデフォルトブランチ）
/dev #123 --quick          # Plan モードを省略（小さな修正向け）
```

#### `/rv`（review）

```text
/rv                       # ブランチ差分（分岐点から + 未コミット分）
/rv --staged              # ステージ済みのみ
/rv #45                   # PR をレビューし、承認後にコメント投稿
/rv backend/app/domain/   # 既存コードの監査
/rv --deep                # 規模に関係なく全 reviewer を起動
/rv --fix                 # CRITICAL/HIGH を修正して再検証
```

変更ファイルを分類して、必要な reviewer だけを並列で起動します。小さな差分ではサブエージェントを使わず、1 パスでレビューします。各 reviewer は確信度付きで指摘を網羅的に返し、`/rv` が CRITICAL/HIGH をコードで裏取りしてから報告します（Opus 4.7 以降のモデルは「重要なものだけ報告」と指示すると見落としが増えるため、絞り込みを別の段階に分けています）。

Claude Code 組み込みの `/init`, `/review`, `/code-review`, `/security-review` とは名前が衝突しないようにしています。

---

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
├── mcp/                       # 将来追加する MCP サーバー用（mcp/README.md 参照）
└── .claude/                   # このリポジトリ自身の開発用（packs/ への symlink と /model-tune）
```

---

## 旧バージョンからの移行

- **install.sh で入れていた場合:** 同じコマンドを再実行してください。旧バージョンで入れた全 pack 分のファイルのうち、選ばれなかった pack のものや、廃止したスキル・agent（`dev-wt`, `code-review`, `clean-arch-guard` など）、旧フォーマット hook（`format-file.sh`）が「不要」として一覧に出ます。`--prune` を付けると削除されます。
- **`my-claude-code` プラグインを入れていた場合:** `/plugin uninstall my-claude-code@yuya-claude-code` の後、必要な pack（または `all`）を入れ直してください。スキル名は `/my-claude-code:rv` から `/review:rv` のように変わります。

---

## MCP サーバーの追加

将来の MCP サーバーは `mcp/` 配下に 1 サーバー = 1 プラグインで追加し、`.claude-plugin/marketplace.json` にエントリを足します。手順は [mcp/README.md](mcp/README.md) を参照してください。

---

## 貢献

[CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。
