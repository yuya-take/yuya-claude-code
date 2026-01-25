# yuya-claude-code

Claude Code用の設定集。agents, skills, hooks, commands, rules, MCP設定をまとめたプラグイン。

> このリポジトリは [affaanmustafa/everything-claude-code](https://github.com/affaanmustafa/everything-claude-code) をフォークし、自分用にカスタマイズしたものです。

---

## 構成

```
yuya-claude-code/
|-- .claude-plugin/   # プラグイン・マーケットプレース設定
|   |-- plugin.json         # プラグインメタデータとコンポーネントパス
|   |-- marketplace.json    # マーケットプレースカタログ
|
|-- agents/           # 特化型サブエージェント
|   |-- planner.md           # 機能実装計画
|   |-- architect.md         # システム設計判断
|   |-- tdd-guide.md         # テスト駆動開発
|   |-- code-reviewer.md     # 品質・セキュリティレビュー
|   |-- security-reviewer.md # 脆弱性分析
|   |-- build-error-resolver.md
|   |-- e2e-runner.md        # Playwright E2Eテスト
|   |-- refactor-cleaner.md  # 不要コード削除
|   |-- doc-updater.md       # ドキュメント同期
|
|-- skills/           # ワークフロー定義・ドメイン知識
|   |-- coding-standards/           # 言語別ベストプラクティス
|   |-- backend-patterns/           # API, データベース, キャッシュパターン
|   |-- frontend-patterns/          # React, Next.jsパターン
|   |-- continuous-learning/        # セッションからパターン自動抽出
|   |-- strategic-compact/          # 手動コンパクション提案
|   |-- tdd-workflow/               # TDD手法
|   |-- security-review/            # セキュリティチェックリスト
|   |-- eval-harness/               # 検証ループ評価
|   |-- verification-loop/          # 継続的検証
|
|-- commands/         # スラッシュコマンド
|   |-- tdd.md              # /tdd - テスト駆動開発
|   |-- plan.md             # /plan - 実装計画
|   |-- e2e.md              # /e2e - E2Eテスト生成
|   |-- code-review.md      # /code-review - 品質レビュー
|   |-- build-fix.md        # /build-fix - ビルドエラー修正
|   |-- refactor-clean.md   # /refactor-clean - 不要コード削除
|   |-- learn.md            # /learn - セッション中パターン抽出
|   |-- checkpoint.md       # /checkpoint - 検証状態保存
|   |-- verify.md           # /verify - 検証ループ実行
|   |-- setup-pm.md         # /setup-pm - パッケージマネージャー設定
|
|-- rules/            # 常時適用ルール（~/.claude/rules/にコピー）
|   |-- security.md         # 必須セキュリティチェック
|   |-- coding-style.md     # イミュータビリティ、ファイル構成
|   |-- testing.md          # TDD、80%カバレッジ要件
|   |-- git-workflow.md     # コミット形式、PRプロセス
|   |-- agents.md           # サブエージェント委譲タイミング
|   |-- performance.md      # モデル選択、コンテキスト管理
|
|-- hooks/            # トリガーベース自動化
|   |-- hooks.json                # 全フック設定（PreToolUse, PostToolUse, Stop等）
|   |-- memory-persistence/       # セッションライフサイクルフック
|   |-- strategic-compact/        # コンパクション提案
|
|-- scripts/          # クロスプラットフォームNode.jsスクリプト
|   |-- lib/                     # 共有ユーティリティ
|   |   |-- utils.js             # ファイル/パス/システムユーティリティ
|   |   |-- package-manager.js   # パッケージマネージャー検出・選択
|   |-- hooks/                   # フック実装
|   |   |-- session-start.js     # セッション開始時コンテキスト読み込み
|   |   |-- session-end.js       # セッション終了時状態保存
|   |   |-- pre-compact.js       # コンパクション前状態保存
|   |   |-- suggest-compact.js   # 戦略的コンパクション提案
|   |   |-- evaluate-session.js  # セッションからパターン抽出
|   |-- setup-package-manager.js # 対話式PM設定
|
|-- tests/            # テストスイート
|   |-- lib/                     # ライブラリテスト
|   |-- hooks/                   # フックテスト
|   |-- run-all.js               # 全テスト実行
|
|-- contexts/         # 動的システムプロンプト注入コンテキスト
|   |-- dev.md              # 開発モードコンテキスト
|   |-- review.md           # コードレビューモードコンテキスト
|   |-- research.md         # リサーチ/探索モードコンテキスト
|
|-- examples/         # 設定例・セッション例
|   |-- CLAUDE.md           # プロジェクトレベル設定例
|   |-- user-CLAUDE.md      # ユーザーレベル設定例
|
|-- mcp-configs/      # MCPサーバー設定
|   |-- mcp-servers.json    # GitHub, Supabase, Vercel, Railway等
```

---

## インストール

### プラグインとしてインストール（推奨）

```bash
# マーケットプレースに追加
/plugin marketplace add yuya-take/yuya-claude-code

# プラグインをインストール
/plugin install yuya-claude-code@yuya-claude-code
```

または `~/.claude/settings.json` に直接追加：

```json
{
  "extraKnownMarketplaces": {
    "yuya-claude-code": {
      "source": {
        "source": "github",
        "repo": "yuya-take/yuya-claude-code"
      }
    }
  },
  "enabledPlugins": {
    "yuya-claude-code@yuya-claude-code": true
  }
}
```

### 手動インストール

```bash
git clone https://github.com/yuya-take/yuya-claude-code.git

# 必要なものをコピー
cp yuya-claude-code/agents/*.md ~/.claude/agents/
cp yuya-claude-code/rules/*.md ~/.claude/rules/
cp yuya-claude-code/commands/*.md ~/.claude/commands/
cp -r yuya-claude-code/skills/* ~/.claude/skills/
```

hooksは `hooks/hooks.json` から `~/.claude/settings.json` にコピー。
MCPは `mcp-configs/mcp-servers.json` から `~/.claude.json` にコピー（APIキーは要置換）。

---

## 主な概念

### Agents
限定スコープでタスクを処理するサブエージェント。

```markdown
---
name: code-reviewer
description: コードの品質・セキュリティ・保守性をレビュー
tools: Read, Grep, Glob, Bash
model: opus
---

あなたはシニアコードレビュアーです...
```

### Skills
コマンドやエージェントから呼び出されるワークフロー定義。

```markdown
# TDD Workflow

1. インターフェース定義
2. 失敗するテスト作成（RED）
3. 最小限の実装（GREEN）
4. リファクタリング（IMPROVE）
5. 80%以上のカバレッジ確認
```

### Hooks
ツールイベントで発火する自動化。

```json
{
  "matcher": "tool == \"Edit\" && tool_input.file_path matches \"\\\\.(ts|tsx|js|jsx)$\"",
  "hooks": [{
    "type": "command",
    "command": "#!/bin/bash\ngrep -n 'console\\.log' \"$file_path\" && echo '[Hook] Remove console.log' >&2"
  }]
}
```

### Rules
常時適用ガイドライン。モジュール化して管理。

```
~/.claude/rules/
  security.md      # シークレットハードコード禁止
  coding-style.md  # イミュータビリティ、ファイル制限
  testing.md       # TDD、カバレッジ要件
```

---

## テスト

```bash
# 全テスト実行
node tests/run-all.js

# 個別テスト
node tests/lib/utils.test.js
node tests/lib/package-manager.test.js
node tests/hooks/hooks.test.js
```

---

## パッケージマネージャー検出

プラグインは自動でパッケージマネージャー（npm, pnpm, yarn, bun）を検出。優先順位：

1. 環境変数: `CLAUDE_PACKAGE_MANAGER`
2. プロジェクト設定: `.claude/package-manager.json`
3. package.json: `packageManager`フィールド
4. ロックファイル検出
5. グローバル設定: `~/.claude/package-manager.json`
6. フォールバック: 利用可能な最初のPM

```bash
# 設定
node scripts/setup-package-manager.js --project pnpm

# 検出確認
node scripts/setup-package-manager.js --detect
```

---

## 注意事項

### コンテキストウィンドウ管理

MCPを全て有効にすると200kのコンテキストが70kまで圧迫される可能性あり。

推奨：
- 20-30個のMCPを設定
- プロジェクトごとに10個以下を有効化
- 80ツール以下をアクティブに

`disabledMcpServers`でプロジェクト単位で無効化。

---

## ライセンス

MIT
