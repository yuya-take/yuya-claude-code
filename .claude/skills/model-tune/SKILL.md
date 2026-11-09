---
name: model-tune
description: 新しい Claude モデルのリリースや Claude Code の仕様変更に合わせて、配布物（packs/ 配下の各 pack の skills・agents・rules・hooks・permissions）を公式ドキュメントと突き合わせて点検し、修正案を出して適用する。新モデルが出たとき、または Claude Code のスキル・agent・settings の仕様が変わったときに実行する。
argument-hint: "[対象モデル名 or モデル ID（省略時は最新の Opus）]"
disable-model-invocation: true
---

# /model-tune

引数: `$ARGUMENTS`

配布物の文面は、書いた時点のモデルの癖に合わせて調整されている。モデルが変わると、前のモデル向けの対策がそのまま逆効果になることがある（強調表現が過剰反応を招く、報告の絞り込み指示で見落としが増える、検証の指示が過剰な検証を招く、など）。このスキルは、そうした箇所を公式の一次情報を根拠に見つけて直す。

根拠にするのは、このスキルの実行中に取得した公式ドキュメントに書かれていることだけ。モデルや Claude Code の仕様は学習データより新しいことが多いので、記憶にある仕様は使わない。

## 1. 前回からの差分を把握する

`${CLAUDE_SKILL_DIR}/history.md` を読み、前回の対象モデル・Claude Code のバージョン・反映した変更を確認する。

対象モデルは、引数で指定があればそれ、無ければ公式のモデル一覧で最新の Opus にする。前回と同じモデルなら、Claude Code 側の仕様変更だけを点検すればよい。

## 2. 公式情報を集める

モデル側と Claude Code 側は互いに独立しているので、それぞれ 1 つずつサブエージェントに調べさせ、並列で進めてよい。調査ログを持ち込まず、要点だけを受け取れるため。

**モデル側（対象モデルの特性）**
- `claude-api` スキルを読み込み、同梱の `shared/model-migration.md` から対象モデルの節（Behavioral shifts と Migration Checklist）を、`shared/prompt-audit.md` を全文読む。`prompt-audit.md` は、古いモデル向けの書き方を見つけるための判定基準で、ステップ 3 の点検の基準になる
- https://platform.claude.com/llms.txt からページ一覧をたどり、対象モデルの「What's new」「Prompting Claude <モデル名>」、移行ガイド、effort のページを読む

**Claude Code 側（配布物の書式と設定）**
- https://code.claude.com/docs/llms.txt からページ一覧をたどり、次を読む: skills（frontmatter と文字列置換）、sub-agents（frontmatter、model エイリアス、effort）、model-config（effort の既定値と解決順）、settings reference と permissions、hooks、組み込みコマンドの一覧
- claude-code-guide エージェントに聞いてもよい。ただし、回答に出てきた設定キーや値の型は、ドキュメント本文で確かめてから使う

集めた内容を、次の観点で「モデルプロファイル」として短くまとめる。ステップ 3 の点検と、ステップ 6 の記録に使う。
- effort の既定値と推奨の使い分け、思考の扱い（常にオンか、無効にできるか）
- 前のモデルからの挙動の変化: 応答の長さ、サブエージェントの使い方、自己検証、タスクの範囲の広げ方、指示への従い方、途中経過の出し方、レビュー時の報告の絞り方
- 公式が削除・書き換えを勧めている指示のパターン
- Claude Code で追加・廃止・変更された frontmatter フィールド、エイリアスの解決先、設定キー、permission の書式、組み込みコマンド

## 3. 配布物を点検する

対象は `packs/` 配下（各 pack の skills・agents・rules・hooks・`project-settings.json`・`.claude-plugin/plugin.json`）、`install.sh`、`README.md`。このリポジトリの `.claude/skills/` と `.claude/agents/` の大半は `packs/` への symlink なので、リンク先を点検すれば足りる。

`prompt-audit.md` のパターン（圧力表現、API 機能で置き換わった足場、手順の過剰指定、旧モデル向けの名残、設定ファイルの陳腐化）と、ステップ 2 のモデルプロファイルを基準に見る。次の点は、配布物の性質上ずれやすいので毎回確認する。
- reviewer agent と `/rv` の報告ルール: 絞り込みの指示が、見落としを増やす方向に働いていないか
- `/dev`・`/rv` などのサブエージェントの使い方: 起動数が多すぎないか、自分の作業の検証をサブエージェントに任せていないか
- frontmatter の `model` / `effort` / `tools` などが現行の仕様で有効か。既定値やエイリアスの解決先が変わって、意図とずれていないか
- settings テンプレートのキーと permission の書式が現行の仕様で有効か。古いバージョンの Claude Code で読めなくなる書き方をしていないか
- スキル名が組み込みコマンドと衝突していないか

`prompt-audit.md` の keep list に当たるものは残す。具体的には、プロジェクト固有の文脈、破壊的な操作の手順、投稿前の承認ステップ、理由の付いた禁止事項。

## 4. 報告して承認を得る

指摘ごとに、場所（`file:line`）、該当箇所の引用、根拠（公式ページの URL か、同梱リファレンスの節）、重要度、修正案を示す。根拠を示せないものは「要確認」として別にまとめ、修正案には含めない。指摘が無ければ、そう報告して終える。

修正はユーザーの承認を得てから行う。

## 5. 修正と検証

`main` から作業ブランチを切って、承認された範囲を修正する。修正後に次を確認する。
- `claude plugin validate .`
- `bash -n install.sh` と `bash -n packs/*/hooks/*.sh`、`packs/*/project-settings.json` と `packs/*/.claude-plugin/plugin.json` が JSON として読めること
- 一時ディレクトリで `install.sh`（既定の選択、`--packs all`、`--only rules,settings`）を実行し、展開と settings のマージが通ること
- スキルや agent を削除・改名した場合は、参照が残っていないことを grep で確認する（README の pack 一覧、`marketplace.json`、`rules/agents.md`、`/rv` の振り分け表、`install.sh` の `DEPRECATED`、`.claude/` の symlink）

## 6. 記録して PR にする

`${CLAUDE_SKILL_DIR}/history.md` の先頭に、今回の記録を追加する。内容は、日付、対象モデル、Claude Code のバージョン（`claude --version`）、参照した主な公式ページ、モデルプロファイルの要点、反映した変更の要約。

その後、`/pr` でコミットと PR の作成に進む。
