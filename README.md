# yuya-claude-code

自分用の Claude Code 設定集です。用途ごとの **pack** に分かれていて、プロジェクトに必要な pack だけを `.claude/` に展開して使います。

実戦投入されている agents, skills, rules, hooks をベースにしています。

---

## pack

| pack | 中身 | 依存 |
|------|------|------|
| `core` | `/setup`（展開とプロジェクトに合わせた調整）、`/explain`、`/skill-create`（git 履歴からスキル生成）、Git ワークフローの rule、基本の permissions | — |
| `review` | `/rv`（統合レビュー）、`/refactor-clean`、reviewer agent 一式、agents rule | core |
| `dev-flow` | `/issue-create`・`/issue-refine`（Issue の作成と詳細化）、`/dev`（Issue から設計・実装・セルフレビュー）、`/orchestrate`（複数 Issue の並行実装）、`/pr`、`/sync` | core, review |
| `python` | Python / 命名 / Clean Architecture / DB の rules、`/troubleshooting`（サービス起動・DB・マイグレーションの対処）、ruff の自動フォーマット、uv・pytest の permissions | core |
| `frontend` | `/unslop-design`（画面の AI っぽいデザインを点検し、UI/UX から考え直した画面に作り替える）、TypeScript / React / Orval の rules、biome の自動フォーマット、npm の permissions | core |
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

#### `/orchestrate`（dev-flow）

```text
/orchestrate #121 #122 #123 #125            # 複数の Issue を並行して実装（同時実行は既定 3）
/orchestrate #121 #122 --max 2 --base main
/orchestrate --label ready                  # ラベルで選ぶ
/orchestrate --milestone v1.2               # マイルストーンで選ぶ
/orchestrate --parent #100                  # 親 Issue の直下のサブ Issue を選ぶ
/orchestrate --resume                       # 閉じたオーケストレータを再開する
```

このセッションがオーケストレータになり、Issue ごとに裏で動く作業セッション（`claude --bg`）を起動して `/dev` を実行させます。

- **投入計画:** 起動の前に Issue を読み、同じファイルを触るものや依存があるものは別の波に分けた計画を示して、承認を得ます。他の人が担当している Issue は保留にします。同時実行数より多い Issue は、空きができるたびに順に起動します。
- **計画の承認:** 作業セッションが立てた実装計画は、Issue の範囲内で他の作業と衝突しなければオーケストレータが承認します。範囲外の変更や仕様の判断を含むものは、あなたに確認します。
- **質問への回答:** 作業セッションからの質問には、オーケストレータが答えます。仕様の判断が要るものは、あなたに聞いてから返します。
- **完了:** 各作業セッションは `/pr` で PR を作って報告します。オーケストレータが PR の一覧とマージ順をまとめます。マージはあなたが行います。
- **GitHub への反映:** 投入計画の承認時に選べます。選ぶと、起動時に Issue の担当者を自分にし、作業中を表すラベル（`in progress` など、既にあるもの）を付けます。PR ができたらラベルを外します。

進み具合は `.orchestrate/state.md` に記録されます（ディレクトリごと git の管理から外れます）。オーケストレータのセッションを閉じても、`/orchestrate --resume` で続きから再開できます。閉じている間に作業セッションが送れなかった連絡は、再開後に送り直されます。

作業セッションは `claude agents`（agent view）で一覧でき、途中で中に入って操作できます。作業セッションに出る permission の確認には、オーケストレータは答えられません（別セッションからのメッセージは承認として扱われない仕様のため）。確認が出たら agent view で答えてください。

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

#### `/unslop-design`（frontend）

```text
/unslop-design                        # 全画面を点検して一覧を出し、作り替える画面を選ぶ
/unslop-design app/dashboard/         # 指定した画面を作り替える
/unslop-design /settings/billing      # ルートで指定してもよい
/unslop-design --changed              # 今のブランチで変更した行だけ（/dev で作った画面の仕上げ）
/unslop-design app/page.tsx --audit   # 点検と設計方針だけ（編集しない）
```

画面から、生成 AI が作ったように見えるデザインを見つけ、利用者の目的と操作から考え直した画面に作り替えます。対象は、意味の無いグラデーションや光彩、絵文字のアイコン、煽り文句、飾りの統計カード、どの画面にも同じテンプレートを当てはめた構成などです。

- **目的から構成を決める:** 画面ごとに、利用者・目的・大事な情報・操作の頻度・前後の画面をまとめます。そこから、情報の並びと主な操作の位置を決め直します。ブラウザを操作できるツール（Playwright の MCP など）があれば、主なタスクを実際に操作して、迷う箇所を確かめます。
- **見た目は基盤に揃える:** テーマ（`@theme` / `:root` の色トークン、角丸、書体）と `components/ui/` を先に読み、直書きの値や独自の部品をそこに寄せます。好みのスタイルに作り替えることはしません。基盤がほとんど無いプロジェクトでは、最小限のトークンの案から始めます。
- **候補は機械的に、判断は文脈で:** 同梱の `scan.py` が、グラデーション、パレット色の直指定、スケール外の任意値、繰り返す動き、感嘆符や煽り語などの候補を行単位で拾います。直すかどうかは Claude が周りを見て決めます。
- **編集の前に止まる:** 画面ごとに、指摘の一覧、今の配置と案を並べた配置図、見た目の方針を示し、承認を得てから作り替えます。ほとんど問題が無ければ、そう伝えて終えます。機能とデータは減らさず、API やデータ取得のロジックには触れません。
- **日本語の UI 向け:** 感嘆符、挨拶の見出し、末尾の句点、語尾や表記の揺れ、和文の行間や斜体なども見ます。

`scan.py` の実行には `python3` が必要です。

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
