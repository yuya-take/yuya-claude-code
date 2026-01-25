# yuya-claude-code カスタマイズ TODO

自分の開発スタイルに合わせてカスタマイズするためのチェックリスト。

---

## 自分の技術スタック

- **バックエンド**: Python (FastAPI) / Rust (Axum)
- **フロントエンド**: Next.js / Flutter / React Native
- **アーキテクチャ**: レイヤード（application, domain, adapter, presentation）
- **パッケージ管理**:
  - JavaScript: npm
  - Python: uv
  - Rust: cargo

---

## 完了

- [x] README.md を書き換え
- [x] CONTRIBUTING.md を削除
- [x] MANUAL.md を作成
- [x] .claude-plugin/ の作者情報を更新
- [x] package-manager.json を npm に変更

---

## Phase 1: 不要なものを削除

元のリポジトリは金融プラットフォーム向けだったので、関係ない設定を削除。

### MCP設定（mcp-configs/mcp-servers.json）

- [x] 使わないサービスを削除
  - 削除: vercel, railway, cloudflare系(4個), clickhouse, magic
- [x] 必要なものだけ残す
  - 残した: github, memory, sequential-thinking, context7, filesystem, supabase, firecrawl

### Skills

- [x] `skills/clickhouse-io/` を削除
- [x] `skills/project-guidelines-example/` を削除

---

## Phase 2: 金融プラットフォーム向けの例を削除

### agents/architect.md

- [x] 「Example Project」セクションを削除

### agents/security-reviewer.md

- [x] 「Example Project-Specific Security Checks」を削除

### agents/e2e-runner.md

- [x] 「Example Project-Specific Test Scenarios」を削除
- [x] pmx.trade への参照を削除

### agents/code-reviewer.md

- [x] 「Project-Specific Guidelines」確認済み（テンプレート形式なのでOK）

### skills/continuous-learning/SKILL.md

- [x] 外部リンク（元作者のガイド）を削除

---

## Phase 3: 自分のスタック向けに追加・修正

### skills/backend-patterns/

- [ ] FastAPI のパターンを追加
- [ ] Axum のパターンを追加
- [ ] レイヤードアーキテクチャのパターンを追加
  - application層
  - domain層
  - adapter層
  - presentation層

### skills/frontend-patterns/

- [ ] Next.js パターンを確認（既存で使えるか）
- [ ] Flutter パターンを追加
- [ ] React Native パターンを追加

### 新しいスキル（必要に応じて）

- [ ] `skills/python-patterns/` - Python/FastAPI のベストプラクティス
- [ ] `skills/rust-patterns/` - Rust/Axum のベストプラクティス
- [ ] `skills/flutter-patterns/` - Flutter のベストプラクティス
- [ ] `skills/layered-architecture/` - レイヤードアーキテクチャのガイド

---

## Phase 4: 設定ファイルの調整

### examples/CLAUDE.md

- [ ] 自分のプロジェクト用テンプレートに書き換え
  - レイヤードアーキテクチャの構造
  - 使用技術スタック
  - コーディング規約

### examples/user-CLAUDE.md

- [ ] ユーザーレベルの共通設定を作成

### rules/

- [ ] `rules/testing.md` を確認（pytest, cargo test 向けに調整？）
- [ ] `rules/coding-style.md` を確認

### hooks/hooks.json

- [ ] Python/Rust 向けのフックがあるか確認
- [ ] 不要なフックを無効化

---

## Phase 5: 確認・テスト

- [ ] 実際のプロジェクトでプラグインを試す
- [ ] 使いにくい部分を調整

---

## メモ

（作業中のメモをここに）
