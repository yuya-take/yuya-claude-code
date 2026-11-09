# Git Workflow

## リモート連携 CLI

GitHub 前提。リモート操作（PR / Issue / ラベル）は `gh` CLI を使う。

## ブランチ運用

- **developブランチから作成する**
- PRのターゲットブランチはdevelop
- リリース用ブランチ（main等）が分離されている場合は、直接ブランチを切ったりpushしない

### ブランチ命名

```
feat/123-short-desc      # 機能追加（Issue番号付き）
fix/456-short-desc       # バグ修正
refactor/short-desc      # リファクタリング
perf/short-desc          # パフォーマンス改善
test/short-desc          # テストのみの変更
chore/short-desc         # 設定・CI・依存更新等
docs/short-desc          # ドキュメント
```

Issue がある場合は番号を入れる。英語の kebab-case、50 文字以内。`/dev` はこの規則でブランチを作る。

## コミットメッセージ

### フォーマット

```
<type>(<scope>): <description>

<optional body>
```

### type

`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

### scope（省略可）

変更対象のサービス/領域名（例: `backend`, `frontend`, `infra`, `monitoring`, `dev`）

### 例（実際のコミット履歴に基づく）

```
feat(backend): 新規APIエンドポイントを追加してデータ取得を効率化
fix(frontend): フォームバリデーションエラー時の表示を修正
refactor(backend): repository の返却型を dict から Pydantic モデルに変更
chore: /explain スキルを追加（コードベース説明用）
docs: READMEにClaude Code開発ガイドを追加
```

### ルール

- 日本語で記述（プロジェクト慣習）
- 1行目は簡潔に（70文字目安）
- `Co-Authored-By` は付けない（`.claude/settings.json` の `attribution` で無効化している）

## コミット分割

変更内容に応じて論理的な単位でコミットを分割する:
- 機能追加、リファクタ、バグ修正は別コミット
- 設定変更とコード変更は別コミット
- 関連するファイルはまとめて1コミット

## Pull Request

PR の作成・更新は `/pr` スキルで行う（手順と description の形式はスキル側に定義している）。

## 禁止事項

- リリース用ブランチ（main等）への直接push / ブランチ作成
- `--force` push（`--force-with-lease` も確認してから）
- `--no-verify` でのhookスキップ
- `git reset --hard` / `git checkout .` / `git clean -f`（確認なしでの実行）
- `git rebase -i`（インタラクティブモードは非対応）
- 機密ファイル（`.env`, credentials）のコミット
