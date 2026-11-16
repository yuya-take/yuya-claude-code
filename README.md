# yuya-claude-code

GitHub の Issue を起点に、Claude Code で設計・実装・レビュー・PR の作成まで進めるための設定集です。skills・agents・rules・hooks・permissions を用途ごとの **pack** に分けて配布しています。使い方は 2 通りあります。

- プロジェクトの `.claude/` に展開する
- Claude Code のプラグインとして入れる

中心になるのは `/orchestrate` です。複数の Issue を渡すと、Issue ごとに裏で作業セッションを立ち上げて並行に実装させます。PR がそろうまでの取りまとめも `/orchestrate` が行います。

## 使い方の流れ

1. **Issue を用意する:** `/issue-create` で、対話しながら Issue を作ります。既存の Issue は `/issue-refine` で詳しくできます。受け入れ条件がはっきりしているほど、作業セッションが止まらずに進みます。
2. **`/orchestrate` に渡す:** `/orchestrate --label ready` のように対象を指定します。投入計画が示されるので、承認すると作業セッションが動き出します。
3. **待つ:** 3 分ごとに実装状況の表が出ます。あなたの判断が要るものだけ、選択式の質問で聞かれます。
4. **PR を見てマージする:** 作業セッションが作った PR には、作業中に誰が何を判断したかが載っています。必要なら `/rv #<PR 番号>` でレビューします。マージはあなたが行います。
5. **片付ける:** マージ後、各作業セッションで `/sync` を実行し、セッションを消します。

Issue が 1 件だけなら、`/orchestrate` を通さずに `/dev #123` で実装し、`/pr` で PR を作れます。

## `/orchestrate`（dev-flow）

```text
/orchestrate #121 #122 #123 #125         # Issue を番号で指定する
/orchestrate --label ready               # ラベルで選ぶ
/orchestrate --milestone v1.2            # マイルストーンで選ぶ
/orchestrate --parent #100               # 親 Issue の直下のサブ Issue を選ぶ
/orchestrate #121 #122 --max 2           # 同時に動かす作業セッションの数（既定 3）
/orchestrate --label ready --base main   # 分岐元（既定は develop、無ければデフォルトブランチ）
/orchestrate --resume                    # 閉じたオーケストレータを再開する
```

`/orchestrate` を実行したセッションが、オーケストレータになります。オーケストレータは自分では実装しません。Issue ごとに裏で作業セッション（`claude --bg`）を起動して `/dev` を実行させます。オーケストレータが受け持つのは次の 4 つです。
- 作業セッションの計画の審査
- 作業セッションからの質問への回答
- 実装状況の報告
- PR の取りまとめ

### 投入計画

オーケストレータは、対象の Issue と関連するコードを読み、次をまとめた投入計画を示します。

- **波の分け方:** 同じファイルを触る Issue や、依存のある Issue は別の波に分けます。次の波は、前の波の PR がマージされてから始めます。
- **Issue ごとのモデルと effort:** 基本は最新の Opus で、effort は `xhigh` です。範囲の狭い Issue は `high` にします。Issue に合わせて外すこともあり、そのときは理由を添えます（例: 機械的な変更は Sonnet、Opus では難しいものは Fable）。
- **保留にする Issue:** 要件が曖昧な Issue（先に `/issue-refine` を勧めます）と、他の人が担当している Issue です。

選択式の質問で、2 つのことを聞かれます。
- 計画の承認
- GitHub への反映：起動時に Issue の担当者を自分にし、作業中を表すラベルを付けるか

モデルなどを変えたいときは、質問の「Other」に書きます。

### 実装中

作業セッションは auto モードで動きます。次の操作は確認なしで進みます。
- 編集
- テスト
- lock ファイルにある依存の導入
- 自分のブランチへの push
- PR の作成

作業セッションからの連絡は、オーケストレータが受けます。

| 連絡 | オーケストレータの対応 |
|---|---|
| 実装計画 | Issue の範囲内で、他の作業と衝突しなければ承認する |
| 質問 | Issue・コード・これまでの判断から答えられるものは答える |
| auto モードに止められた操作（force push、既存ファイルの削除など） | 代わりの方法で済むもの、不要なものは、進め方を指示する |

次のものだけ、あなたに聞きます。

- 仕様やプロダクトの判断
- Issue の範囲を超える変更、DB スキーマや公開 API の互換性を崩す変更
- auto モードに止められ、代わりの方法では済まない操作（承認すると、オーケストレータがその操作を実行します）
- `.worktreeinclude` にない、秘密を含むファイルを作業セッションに渡すこと

質問は、本文ではなく選択式のダイアログ（`AskUserQuestion`）で出ます。報告が流れても、答えるまで画面に残ります。ダイアログは 1 回 4 問までなので、多いときは作業を止めているものから順に聞きます。

### 実装状況の報告

作業中のセッションがある間、3 分ごとに次のような表が出ます。

```text
## 実装状況（14:03）
| Issue | セッション | モデル / effort | 状態 | 進捗 | PR |
|---|---|---|---|---|---|
| #121 | dev-121 | opus / xhigh | 検証中（作業中） | 6 ファイル変更（+120 −8）、コミット 2 | — |
| #122 | dev-122 | opus / high | ユーザーの判断待ち（待機中） | エラー文言をどうするか | — |
| #125 | dev-125 | sonnet / high | 完了 | — | #130 |
```

「状態」は、作業セッションが知らせる段階（実装・検証・セルフレビュー・PR の作成）です。「進捗」は、変更したファイル数とコミット数です。作業中のセッションが無くなると報告は止まり、作業が再開するとまた出ます。

### 完了とマージ

各作業セッションは `/pr` で PR を作ります。オーケストレータは、PR の本文に「承認を求めた判断」の表を足します。表には、作業中の計画・質問・操作の許可のそれぞれについて、判断したのがオーケストレータかあなたかが載ります。すべての Issue が終わると、PR の一覧、マージ順、残課題をまとめて報告します。マージはあなたが行います。

マージ後は、各作業セッションに入って `/sync` を実行し、Worktree とブランチを片付けます。その後、`claude rm <ジョブ ID>` か agent view でセッションを消します。

### 中断と再開

進み具合は `.orchestrate/state.md` に記録されます（git の管理からは外れます）。オーケストレータのセッションを閉じても、`/orchestrate --resume` で続きから再開できます。閉じている間に作業セッションが送れなかった連絡は、再開後に送り直されます。

### 注意

- 作業セッションは、`claude agents`（agent view）で一覧でき、中に入って操作することもできます。普段は見なくて構いません。
- 作業セッション自身に permission の確認が出た場合は、オーケストレータは答えられません。別セッションからのメッセージは、承認として扱われない仕様のためです。
  - 起きるのは、auto モードが使えない環境や、auto モードが続けて操作を止めて一時停止した場合です。
  - オーケストレータが気づいて質問で知らせるので、agent view でそのセッションに入って答えてください。
- 作業セッション 1 つが、通常のセッション 1 つ分のトークンを使います。3 分ごとの報告でも、そのたびにオーケストレータのトークンを使います。
- 次の機能とツールを使います。
  - Claude Code のセッション間メッセージ（v2.1.224 以降）
  - 手すきの通知（v2.1.236 以降）
  - auto モード
  - `jq`
- プラグインとして入れた場合、スキル名は `/dev-flow:orchestrate` です。

## セットアップ

### 前提条件

- リポジトリが **GitHub** でホストされていること
- [`gh` CLI](https://cli.github.com/) がインストール・認証済み（`gh auth login`）であること
- `python3` と `git` があること（install.sh が使います）

ベースブランチは、`develop` があればそれを、無ければリモートのデフォルトブランチ（`main` など）を使います。

### 1. pack を展開する

対象プロジェクトのルートで実行します。

```bash
curl -fsSL https://raw.githubusercontent.com/yuya-take/yuya-claude-code/main/install.sh | bash
```

`--packs` を指定しない初回は、`core`・`review`・`dev-flow` と、検出した言語の pack を入れます。言語は、次のファイルがあるかで判断します。

| ファイル | 入れる pack |
|---|---|
| `pyproject.toml` / `requirements.txt` | python |
| `package.json` | frontend |
| `Cargo.toml` | rust |

2 回目以降は、前回と同じ pack を使います。

```bash
# 入れる pack を指定する（依存する pack は自動で追加）
curl -fsSL .../install.sh | bash -s -- --packs dev-flow,python,rust

# 全部入れる
curl -fsSL .../install.sh | bash -s -- --packs all

# pack の一覧と、このプロジェクトでの選択を表示する
curl -fsSL .../install.sh | bash -s -- --list
```

`.claude/` には skills / agents / rules / hooks が展開されます。`.claude/settings.json` には、選んだ pack の permissions、自動フォーマットの hook、attribution の設定がマージされます。

- **更新:** 同じコマンドを再実行します。手元で変更していないファイルは、配布元の最新版に更新されます。
- **手元で変更したファイル:** 上書きせず、スキップして一覧に出します。上書きするには `--force` を付けます。
- **不要になったファイル:** pack を外したときや、廃止したスキル・agent が残っているときは、一覧に出します。`--prune`（`--force` にも含まれる）を付けると削除します。削除するのは、このスクリプトが入れたもので、かつ手元で変更していないファイルだけです。
- **`settings.json`:** 足りない設定を追加するだけで、既存の設定は消しません。
- **導入記録:** 入れた pack とファイルは `.claude/.yuya-claude-code.json` に記録されます。チームで共有する場合は、`.claude/` ごとコミットしてください。

<details>
<summary>別の方法: プラグインとして入れる</summary>

Claude Code 内で marketplace を追加してから、必要な pack を入れます。依存する pack は自動で入ります。

```shell
/plugin marketplace add yuya-take/yuya-claude-code
/plugin install dev-flow@yuya-claude-code
/plugin install python@yuya-claude-code
# 全部入れる場合
/plugin install all@yuya-claude-code
```

スキル名には pack 名が付きます（例: `/dev-flow:orchestrate`, `/review:rv`, `/core:setup`）。

rules と permissions は、プラグインの仕組みでは配布されません。続けて `/core:setup` を実行してください。入れた pack の rules と permissions を展開し、プロジェクトに合わせた調整まで行います。

更新するときは、`/plugin marketplace update yuya-claude-code` の後に、各 pack を `/plugin update` します。

</details>

### 2. プロジェクトに合わせる

対象プロジェクトで Claude Code を起動し、`/setup` を実行します。プロジェクトの構造を調べて、次を行います。

- 環境のチェック（GitHub のリモート、`gh` CLI の導入と認証、ベースブランチ、Worktree 用の `.gitignore`）
- rules の `paths:` と例を、プロジェクトの実際のディレクトリやコマンドに合わせる
- `settings.json` の permissions を、プロジェクトで使うコマンドに合わせる
- `/rv` の振り分け表や `test-runner` のテストコマンドを、実際の構成に合わせる

プロジェクトの構成が変わったときも、再実行すれば更新できます。

## pack とスキル

| pack | 中身 | 依存 |
|------|------|------|
| `core` | `/setup`、`/explain`、`/skill-create`、Git ワークフローの rule、基本の permissions | — |
| `review` | `/rv`、`/refactor-clean`、reviewer agent 一式、agents の rule | core |
| `dev-flow` | `/issue-create`、`/issue-refine`、`/orchestrate`、`/dev`、`/pr`、`/sync` | core, review |
| `python` | Python・命名・Clean Architecture・DB の rules、`/troubleshooting`、ruff の自動フォーマット、uv・pytest の permissions | core |
| `frontend` | `/unslop-design`、TypeScript・React・Orval の rules、biome の自動フォーマット、npm の permissions | core |
| `rust` | Rust の rules、cargo の permissions | core |

依存する pack は、自動で一緒に入ります。reviewer agent は、言語に関係なくすべて `review` に入っています。`/rv` は変更されたファイルに合う reviewer だけを起動するので、使わない言語の reviewer は動きません。

| スキル | pack | すること |
|---|---|---|
| `/issue-create` | dev-flow | 対話しながら、コードを調べて Issue を作る |
| `/issue-refine` | dev-flow | 曖昧な Issue を、コードを調べて詳しくする |
| `/orchestrate` | dev-flow | 複数の Issue を、作業セッションで並行に実装させる |
| `/dev` | dev-flow | Issue 1 件を、設計・実装・テスト・セルフレビューまで進める |
| `/pr` | dev-flow | 変更をコミットに分けてプッシュし、PR を作る・更新する |
| `/sync` | dev-flow | ベースブランチを最新にし、マージ済みのブランチと Worktree を片付ける |
| `/rv` | review | 変更に合う reviewer を並列で動かしてレビューする |
| `/refactor-clean` | review | 使われていないコードや依存を、テストで確かめながら消す |
| `/setup` | core | 入れた pack をプロジェクトに合わせる |
| `/explain` | core | コードベースの仕組みを調べて説明する |
| `/skill-create` | core | git の履歴から、チームの作業パターンをスキルにする |
| `/troubleshooting` | python | サービスの起動、DB 接続、マイグレーションの問題を解く |
| `/unslop-design` | frontend | AI が作ったように見える画面を、目的から考え直して作り替える |

スキル名は、Claude Code 組み込みのコマンド（`/init`, `/review`, `/code-review`, `/security-review` など）と重ならないようにしています。

### `/dev`（dev-flow）

```text
/dev #123                  # Worktree で開発する（既定）
/dev #123 --branch         # 今のリポジトリでブランチを切って開発する
/dev "CSV 出力を追加"       # Issue なしでもよい
/dev #123 --base feat/epic # 分岐元を指定する（既定は develop、無ければデフォルトブランチ）
/dev #123 --plan           # 実装の前に、計画の承認を待つ（大きな変更向け）
```

Issue を読み、設計、実装、テスト、セルフレビュー（`/rv --inline`）まで進めます。計画を示したら、そのまま実装に進みます。次の場合は、計画を示して承認を待ちます。
- `--plan` を付けたとき
- DB スキーマの変更など取り消しにくい変更や、Issue の範囲を超える変更を含むとき

終わったら、`/pr` で PR を作れます。`/orchestrate` の作業セッションも、中ではこの `/dev` を動かしています（その場合、PR の作成まで自動で進みます）。

### `/rv`（review）

```text
/rv                       # ブランチの差分（分岐点から + 未コミット分）
/rv --staged              # ステージ済みの変更だけ
/rv #45                   # PR をレビューし、承認後にコメントを投稿する
/rv backend/app/domain/   # 既存コードを監査する
/rv --deep                # 規模に関係なく、すべての reviewer を起動する
/rv --fix                 # CRITICAL/HIGH を直して、もう一度確かめる
```

変更されたファイルを分類して、必要な reviewer だけを並列で起動します。小さな差分では、サブエージェントを使わずに 1 回で見ます。CRITICAL/HIGH の指摘は、コードで裏を取ってから報告します。

### `/unslop-design`（frontend）

```text
/unslop-design                        # 全画面を点検して一覧を出し、作り替える画面を選ぶ
/unslop-design app/dashboard/         # 指定した画面を作り替える
/unslop-design /settings/billing      # ルートで指定してもよい
/unslop-design --changed              # 今のブランチで変更した行だけ（/dev で作った画面の仕上げ）
/unslop-design app/page.tsx --audit   # 点検と設計方針だけ（編集しない）
```

画面から、生成 AI が作ったように見えるデザインを見つけ、利用者の目的と操作から考え直した画面に作り替えます。対象は、意味の無いグラデーションや光彩、絵文字のアイコン、煽り文句、飾りの統計カード、どの画面にも同じテンプレートを当てはめた構成などです。

- **目的から構成を決める:** 画面ごとに、利用者・目的・大事な情報・操作の頻度・前後の画面をまとめ、情報の並びと主な操作の位置を決め直します。ブラウザを操作できるツール（Playwright の MCP など）があれば、主なタスクを実際に操作して、迷う箇所を確かめます。
- **見た目は基盤に揃える:** テーマ（`@theme` / `:root` の色トークン、角丸、書体）と `components/ui/` を先に読み、直書きの値や独自の部品をそこに寄せます。好みのスタイルに作り替えることはしません。基盤がほとんど無いプロジェクトでは、最小限のトークンの案から始めます。
- **候補は機械的に、判断は文脈で:** 同梱の `scan.py` が、グラデーション、パレット色の直指定、スケール外の任意値、繰り返す動き、感嘆符や煽り語などの候補を行単位で拾います。直すかどうかは、Claude が周りを見て決めます。
- **編集の前に止まる:** 画面ごとに、指摘の一覧、今の配置と案を並べた配置図、見た目の方針を示し、承認を得てから作り替えます。ほとんど問題が無ければ、そう伝えて終えます。機能とデータは減らさず、API やデータ取得のロジックには触れません。
- **日本語の UI 向け:** 感嘆符、挨拶の見出し、末尾の句点、語尾や表記の揺れ、和文の行間や斜体なども見ます。

`scan.py` の実行には `python3` が必要です。

## 旧バージョンからの移行

- **install.sh で入れていた場合:** 同じコマンドを再実行してください。次のファイルが「不要」として一覧に出るので、`--prune` を付けて削除します。
  - 選ばれなかった pack のファイル
  - 廃止したスキル・agent（`dev-wt`, `code-review`, `clean-arch-guard` など）
  - 旧フォーマットの hook（`format-file.sh`）
- **`my-claude-code` プラグインを入れていた場合:** `/plugin uninstall my-claude-code@yuya-claude-code` の後、必要な pack（または `all`）を入れ直してください。スキル名は `/my-claude-code:rv` から `/review:rv` のように変わります。

## 貢献

Issue や PR を歓迎します。手順とリポジトリの構成は、[CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT License](LICENSE)
