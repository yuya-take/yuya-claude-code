---
name: python-review
description: Python変更ファイルに対して静的解析実行＋手動レビューを行う。ruff/ty/pip-auditの実行とFastAPI/Pydantic/Clean Architectureの観点でチェック。
paths:
  - "**/*.py"
---

# Python Code Review

変更されたPythonファイルに対して、静的解析ツールの実行とコードレビューを行う。

## 手順

### 1. 変更Pythonファイルの特定

```bash
git diff --name-only HEAD -- '*.py'
git diff --name-only --cached -- '*.py'
```

変更がない場合はその旨を報告して終了する。

### 2. 静的解析の実行

変更ファイルが属するサービスディレクトリで以下を実行する:

```bash
# フォーマット + lint（例: プロジェクトの lint コマンドに合わせて変更）
make lint                             # 例: make ruff, uv run ruff check --fix など

# 型チェック（例: プロジェクトの型チェックコマンドに合わせて変更）
# make ty-all                          # 例: mypy, pyright, ty など

# 依存パッケージの脆弱性チェック
uv run pip-audit
```

各ツールの結果を記録する。エラーがあれば修正案とともに報告する。

### 3. 手動コードレビュー

変更ファイルを Read で読み、以下の観点でチェックする。

---

#### CRITICAL（必ず修正）

**セキュリティ**
- [ ] SQLインジェクション — `f"SELECT ... {user_input}"` のような文字列結合
- [ ] RAWクエリにユーザー入力が直接埋め込まれていない
- [ ] `eval()` / `exec()` の使用がない
- [ ] `pickle.loads()` に信頼できないデータを渡していない
- [ ] `yaml.load()` ではなく `yaml.safe_load()` を使用
- [ ] ハードコードされた認証情報がない
- [ ] テナント分離（マルチテナントの場合）: `tenant_id` フィルタリングが漏れていない

**データ整合性**
- [ ] bare `except:` で例外を握りつぶしていない
- [ ] DBトランザクションが適切に管理されている

#### HIGH（修正推奨）

**型安全性**
- [ ] 公開関数に型ヒントがある
- [ ] `str | None` を使用（`Optional[str]` ではない）
- [ ] raw `dict` ではなくPydanticモデルを使用
- [ ] `Any` 型を避けている

**Pythonアンチパターン**
- [ ] ミュータブルデフォルト引数がない（`def f(items=[])` → `def f(items=None)`）
- [ ] コンテキストマネージャを使用（`with open()` 等）
- [ ] リスト内包表記の活用（C言語風ループの回避）
- [ ] f-stringの使用（`.format()` や `+` 結合ではない）
- [ ] ループ内での文字列結合がない（`"".join()` を使用）

**FastAPI固有**
- [ ] リクエスト/レスポンスにPydanticモデルを使用
- [ ] 適切な `async/await` の使用
- [ ] 依存性注入パターンの遵守（`Depends()`）
- [ ] エラーレスポンスに内部情報を漏洩していない

#### MEDIUM（提案）

**命名規則**
- [ ] 命名規則は `.claude/rules/naming-conventions.md` に従う

**Clean Architecture（`.claude/rules/clean-architecture.md` 準拠）**
- [ ] Domain層が外部フレームワークに依存していない
- [ ] App層がDBに直接アクセスしていない
- [ ] レイヤー間の依存方向: Adapter → Domain ← App ← Presentation

**コード品質**
- [ ] 関数が50行を超えていない
- [ ] `print()` が残っていない（`structlog` / プロジェクトのログライブラリを使用）
- [ ] マジックナンバーに名前付き定数を使用
- [ ] TODO/FIXME が新たに追加されていない

---

### 4. レポート生成

```
## Python Review 結果

### 静的解析
- ruff: ✓ / ⚠️ {件数}件
- ty: ✓ / ⚠️ {件数}件
- pip-audit: ✓ / ⚠️ {件数}件

### コードレビュー

#### CRITICAL
- `ファイルパス:行番号` — 問題の説明
  → 修正案

#### HIGH
- `ファイルパス:行番号` — 問題の説明
  → 修正案

#### MEDIUM
- `ファイルパス:行番号` — 問題の説明
  → 修正案

### 総合判定
- CRITICAL/HIGHがある場合: コミット前に修正を推奨
- MEDIUM以下のみ: コミットOK
```

## 注意事項

- 変更されたPythonファイルのみをレビュー対象にする
- 静的解析ツールでエラーが出た場合は自動修正を提案する（例: `make lint` や `uv run ruff check --fix` で大半は修正可能）
- `/code-review` との違い: このスキルはPython特化で静的解析ツールの実行を含む
