# Agent Orchestration

## Available Agents

| Agent | 用途 | トリガー |
|-------|------|---------|
| **code-reviewer** | コード変更全般のレビュー（Python/Rust/Frontend） | コード変更完了後 |
| **python-reviewer** | Python品質・型安全性・Pythonicパターン | Pythonファイル変更後 |
| **rust-reviewer** | 所有権・安全性・非同期パターン | Rustファイル変更後 |
| **security-reviewer** | セキュリティ脆弱性検出（OWASP Top 10） | 認証・入力処理・APIエンドポイント・機密データ処理の変更後 |
| **database-reviewer** | スキーマ設計・クエリ最適化・テナント分離 | DB関連ファイル変更後 |
| **api-spec-reviewer** | APIエンドポイントの一貫性 | route/・presentation/model/変更後 |
| **clean-arch-guard** | Clean Architecture依存方向違反検出 | Python backendファイル変更後 |
| **migration-checker** | マイグレーション漏れ検知 | adapter/model/・models/変更後 |
| **test-runner** | テスト実行と結果分析 | 実装完了後 |
| **refactor-cleaner** | デッドコード・重複検出 | コード整理時 |

## プロアクティブに使用するタイミング

ユーザーの指示がなくても、以下の状況では該当agentを自動的に使用する:

| 状況 | 使用するagent |
|------|-------------|
| Pythonコードを書いた/修正した | **python-reviewer** + **clean-arch-guard** |
| Rustコードを書いた/修正した | **rust-reviewer** |
| APIエンドポイントを追加/変更した | **api-spec-reviewer** + **security-reviewer** |
| DBモデル/マイグレーションを変更した | **database-reviewer** + **migration-checker** |
| 認証・認可・入力処理を変更した | **security-reviewer** |
| 実装が完了した | **test-runner** |
| リファクタリングを行った | **refactor-cleaner** |

## 並列実行

独立したagentは必ず並列で起動する:

```
# GOOD: 並列実行（Python backendの変更後）
同時に起動:
  1. python-reviewer — コード品質チェック
  2. clean-arch-guard — 依存方向チェック
  3. security-reviewer — セキュリティチェック

# BAD: 順次実行（不要な待ち時間）
python-reviewer → 完了を待つ → clean-arch-guard → 完了を待つ → security-reviewer
```

### 変更内容別の並列パターン

**Python backend変更:**
- python-reviewer + clean-arch-guard + security-reviewer（並列）
- → test-runner（上記完了後）

**APIエンドポイント変更:**
- api-spec-reviewer + security-reviewer + clean-arch-guard（並列）
- → test-runner（上記完了後）

**DBモデル/マイグレーション変更:**
- database-reviewer + migration-checker（並列）
- → test-runner（上記完了後）

**Rust変更:**
- rust-reviewer + security-reviewer（並列）

**大規模リファクタリング:**
- refactor-cleaner + clean-arch-guard + python-reviewer（並列）
- → test-runner（上記完了後）
