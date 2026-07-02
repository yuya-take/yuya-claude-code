---
name: setup
description: プラグインに同梱された rules と settings テンプレートをプロジェクトの .claude/ に展開する。プラグイン導入直後やプラグイン更新後に実行。
disable-model-invocation: true
---

# rules / settings のセットアップ

rules（常時適用ガイドライン）と settings.json（permissions）はプラグインの仕組みでは自動配布されないため、
このスキルでプラグイン本体からプロジェクトの `.claude/` にコピーする。

## 配布元の特定

この SKILL.md はプラグインルートの `skills/setup/` に置かれている。
配布元はこの SKILL.md から見て 2 階層上のプラグインルート:

- rules: `<プラグインルート>/rules/*.md`
- settings テンプレート: `<プラグインルート>/templates/settings.json`

## 手順

### Step 1: rules のコピー

`<プラグインルート>/rules/` 内の全 `.md` ファイルを、プロジェクトの `.claude/rules/` にコピーする。

- `.claude/rules/` が無ければ作成する
- **既存の同名ファイルは上書きしない**（プロジェクト側でカスタマイズ済みの可能性があるため）
- 内容が異なる既存ファイルがあった場合は、ファイル名と差分の概要を報告し、上書きするかユーザーに確認する

### Step 2: settings.json のマージ

`<プラグインルート>/templates/settings.json` の `permissions.allow` を、プロジェクトの `.claude/settings.json` にマージする。

- `.claude/settings.json` が無ければテンプレートをそのままコピー
- 既存ファイルがある場合は `permissions.allow` の和集合を取る（既存エントリは削除しない）
- permissions 以外の既存キー（hooks 等）には触らない

### Step 3: 完了報告

- コピー / スキップ / マージしたファイルの一覧を報告する
- 新規セットアップの場合は、続けて `/my-claude-code:init` の実行を案内する
  （プロジェクト構造に合わせて rules の `paths:` や permissions をカスタマイズするため）

## プラグイン更新後の再実行

プラグイン更新で rules が変わった場合もこのスキルを再実行する。
既存ファイルとの差分を提示し、ユーザーの承認を得てから上書きすること。
