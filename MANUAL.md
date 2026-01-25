# yuya-claude-code 使い方マニュアル

このマニュアルでは、各機能の使い方を説明します。

---

## 目次

1. [エージェント（Agents）](#エージェントagents)
2. [スラッシュコマンド（Commands）](#スラッシュコマンドcommands)
3. [フック（Hooks）](#フックhooks)
4. [スキル（Skills）](#スキルskills)
5. [ルール（Rules）](#ルールrules)
6. [開発ワークフロー例](#開発ワークフロー例)

---

## エージェント（Agents）

特定の役割を持つサブエージェント。タスクを委譲して並行処理が可能。

### planner

**役割**: 実装計画の作成と要件分析

**使い方**:

```
/plan リアルタイム通知機能の実装
```

**出力例**:

```markdown
# 実装計画: リアルタイム通知機能

## 要件
- 認証ユーザーのみ
- WebSocket で配信
- 既読管理

## 実装フェーズ
### フェーズ 1: スキーマ設計
### フェーズ 2: API 実装
### フェーズ 3: フロントエンド

## リスク
- HIGH: 認可チェック必須

WAITING FOR CONFIRMATION: 進行してよい？
```

**使うタイミング**:
- 新機能の実装開始時
- 大きなリファクタリング開始時
- 複数ファイルに影響する変更時

---

### architect

**役割**: システム設計と技術的な意思決定

**機能範囲**:
- システムアーキテクチャ設計
- トレードオフ分析
- スケーラビリティ計画

**使うタイミング**:
- 新しいサブシステム追加時
- マイクロサービス化検討時
- キャッシング・DB最適化時

---

### tdd-guide

**役割**: テスト駆動開発の実装サポート

**TDDサイクル**:

```
RED → GREEN → REFACTOR
1. テストを先に書く（失敗確認）
2. 最小限のコード実装（成功させる）
3. リファクタリング（改善）
```

**使い方**:

```
/tdd 市場流動性スコア計算関数
```

**カバレッジ要件**:
- 通常: 80%以上
- 金融計算・認証・セキュリティ: 100%

---

### code-reviewer

**役割**: コード品質とセキュリティレビュー

**チェック項目**:

| 項目 | 重要度 | 例 |
|------|--------|-----|
| セキュリティ | CRITICAL | APIキーのハードコード、SQLインジェクション |
| コード品質 | HIGH | 関数が50行超、ネスト4階層超 |
| パフォーマンス | MEDIUM | N+1クエリ、メモ化なし |
| ベストプラクティス | MEDIUM | console.log、エラーハンドリング欠落 |

**使い方**:

```
/code-review
```

**判定**:
- APPROVE: CRITICAL/HIGH問題なし
- WARNING: MEDIUM問題のみ
- BLOCK: CRITICAL/HIGH問題あり

---

### security-reviewer

**役割**: セキュリティ脆弱性の検出（OWASP Top 10カバー）

**検査範囲**:
- インジェクション（SQL、コマンド）
- 認証の破綻
- 機密データ露出
- XSS
- アクセス制御欠落

---

### build-error-resolver

**役割**: ビルドエラーとTypeScriptエラーの修正

**使い方**:

```
/build-fix
```

**ワークフロー**:

1. エラー収集: `npm run build` の全エラーを把握
2. カテゴリ分類: 型推論、Nullチェック、インポート等
3. 優先順序付け: ビルドを止めているエラーから
4. 最小修正: 必要な部分だけ変更
5. 再検証: 修正後に新しいエラーがないか確認

**成功基準**:
- `npm run build` が成功
- `npx tsc --noEmit` がエラー0
- 変更行数が最小限

---

### e2e-runner

**役割**: Playwright による E2E テストの生成・実行

**使い方**:

```
/e2e ユーザーが市場を検索して詳細を表示する流れ
```

**テスト実行**:

```bash
npx playwright test                  # 全テスト
npx playwright test --headed         # ブラウザ表示
npx playwright test --debug          # デバッグ
npx playwright show-report           # レポート表示
```

---

### refactor-cleaner

**役割**: デッドコード削除と重複コード統合

**検出ツール**:
- knip: 未使用ファイル、エクスポート、依存
- depcheck: 未使用npmパッケージ
- ts-prune: 未使用TypeScriptエクスポート

**使い方**:

```
/refactor-clean
```

---

### doc-updater

**役割**: コード解析による自動ドキュメント生成

**使い方**:

```
/update-docs
```

**生成物**:
- docs/CODEMAPS/INDEX.md
- docs/CODEMAPS/frontend.md
- docs/CODEMAPS/backend.md

---

## スラッシュコマンド（Commands）

### コマンド一覧

| コマンド | 説明 | 用途 |
|---------|------|------|
| `/plan` | 実装計画作成 | 新機能開始時 |
| `/tdd` | TDD実装サポート | コード作成時 |
| `/code-review` | コード品質レビュー | 作成直後 |
| `/build-fix` | ビルドエラー修正 | ビルド失敗時 |
| `/e2e` | E2Eテスト生成 | 重要フロー検証時 |
| `/refactor-clean` | デッドコード削除 | メンテナンス時 |
| `/verify` | 総合検証 | PR前 |
| `/checkpoint` | チェックポイント作成 | 段階完了時 |
| `/learn` | パターン抽出 | 問題解決時 |
| `/setup-pm` | パッケージマネージャー設定 | 初期設定時 |

---

### /plan - 実装計画

```
/plan [機能説明]
```

計画確認まで実装は進まない。「yes」で承認。

---

### /tdd - テスト駆動開発

```
/tdd [機能説明]
```

インターフェース定義 → テスト作成（RED） → 実装（GREEN） → リファクタリング

---

### /code-review - コード審査

```
/code-review
```

`git diff` で変更ファイル取得 → セキュリティ/品質/パフォーマンスチェック

---

### /build-fix - ビルドエラー修正

```
/build-fix
```

エラーを1つずつ修正し、成功するまで繰り返す。

---

### /e2e - E2Eテスト生成

```
/e2e [ユーザーフロー説明]
```

Page Object Modelパターンでテスト生成。

---

### /verify - 総合検証

```
/verify [quick|full|pre-commit|pre-pr]
```

| オプション | 内容 |
|-----------|------|
| quick | ビルド + 型チェック |
| full | ビルド + 型 + リント + テスト + カバレッジ |
| pre-commit | コミット前チェック |
| pre-pr | PR前の全チェック + セキュリティスキャン |

---

### /checkpoint - チェックポイント

```
/checkpoint [create|verify|list] [名前]
```

大型機能の進捗追跡、リファクタリング前後の比較に使用。

---

### /learn - パターン抽出

```
/learn
```

難しい問題を解決したとき、新しいパターンを発見したときに実行。
`~/.claude/skills/learned/` に保存される。

---

### /setup-pm - パッケージマネージャー設定

```
/setup-pm
```

または直接スクリプト実行:

```bash
node scripts/setup-package-manager.js --project pnpm
node scripts/setup-package-manager.js --detect
```

---

## フック（Hooks）

`hooks/hooks.json` で定義。自動実行される処理。

### PreToolUse（ツール実行前）

| フック | 説明 |
|--------|------|
| Tmuxリマインダー | 長時間実行コマンド前にtmux使用を促す |
| Docブロッカー | 不要な.md/.txtファイル作成を防止 |
| Git Pushリマインダー | Push前に変更内容レビューを促す |

### PostToolUse（ツール実行後）

| フック | 説明 |
|--------|------|
| Prettier自動フォーマット | Edit/Write後にJS/TSファイルを自動整形 |
| TypeScript型チェック | .ts/.tsx編集後に`tsc`実行 |
| console.log警告 | JS/TS編集後にconsole.logをスキャン |

### SessionStart（セッション開始時）

- パッケージマネージャー自動検出
- 前セッションのコンテキスト復元

### Stop（セッション終了時）

- console.log監査
- Continuous Learning（パターン自動抽出）

---

## スキル（Skills）

再利用可能なナレッジベース。

### backend-patterns

バックエンド開発パターン集:
- RESTful API設計
- Repositoryパターン
- Serviceパターン
- キャッシング（Redis Cache-Aside）
- エラーハンドリング
- レート制限

### frontend-patterns

React/Next.js開発パターン集:
- コンポジション
- Compound Components
- Custom Hooks
- Context + Reducer
- Memoization
- Code Splitting
- Error Boundary

### tdd-workflow

テスト駆動開発の手順:
- RED → GREEN → REFACTOR
- ユニットテスト（Jest/Vitest）
- 統合テスト
- E2Eテスト（Playwright）

### coding-standards

プロジェクト固有のコーディング規約。

### continuous-learning

セッション終了時に自動でパターン抽出する設定。

### security-review

セキュリティチェックリスト。

### verification-loop

継続的検証の設定。

---

## ルール（Rules）

常時適用されるガイドライン。`~/.claude/rules/` にコピーして使用。

### security.md

- シークレットのハードコード禁止
- 入力検証必須
- SQLインジェクション対策

### coding-style.md

- イミュータビリティ優先
- ファイルサイズ制限
- 関数の長さ制限

### testing.md

- TDD必須
- 80%カバレッジ要件
- テストタイプの使い分け

### git-workflow.md

**コミット形式**:

```
<type>: <description>

<optional body>
```

**typeの種類**:
- feat: 新機能
- fix: バグ修正
- refactor: リファクタリング
- docs: ドキュメント
- test: テスト追加
- perf: パフォーマンス改善
- chore: その他

### agents.md

- 複雑な機能は planner で計画
- コード作成直後は code-reviewer で審査
- 金融機能は security-reviewer で監査

### performance.md

- モデル選択ガイドライン
- コンテキスト管理

---

## 開発ワークフロー例

### 新機能実装

```
1. /plan "機能説明"
   → 計画確認 → "yes"で承認

2. /tdd "機能説明"
   → テスト作成（RED）
   → 実装（GREEN）
   → リファクタリング

3. /code-review
   → 問題があれば修正

4. /e2e "ユーザーフロー"
   → E2Eテスト生成・実行

5. /verify pre-pr
   → 最終検証

6. git add, commit, push
```

### バグ修正

```
1. /tdd "バグの説明"
   → 再現テスト作成（RED）

2. バグ修正（GREEN）

3. /code-review

4. /verify quick

5. commit & push
```

### コードメンテナンス

```
1. /refactor-clean
   → デッドコード削除

2. /verify full

3. /update-docs

4. commit & push
```

---

## トラブルシューティング

### ビルドが失敗する

`/build-fix` を実行。

### テストカバレッジが80%未満

`/tdd` でテスト追加、または `npm run test:coverage` で確認。

### セキュリティ問題

`/code-review` または security-reviewer エージェントでスキャン。

### E2Eテストが不安定

`test.fixme()` で隔離し、Issue作成。原因は通常:
- ネットワークタイミング
- DOM待機不足
- アニメーション衝突

### フックが邪魔

`~/.claude/settings.json` で該当フックをコメントアウト。

---

## ベストプラクティス

1. **計画を立てる**: 複雑な機能は `/plan` から開始
2. **テストを先に**: テストなしのコミットは避ける
3. **レビューは必須**: 自動エージェントのレビューを活用
4. **段階的に進める**: 大きな変更は小分けに
5. **継続的な学習**: `/learn` で有用なパターンを保存
