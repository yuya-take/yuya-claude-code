# Agents

レビュー系の agent は `/rv` が変更内容に応じて振り分けて起動する。通常の会話や実装中に、指示なしでこれらの agent を自分から起動しない（サブエージェントの起動はコストと待ち時間がかかり、/rv の振り分けと重複するため）。ユーザーが特定の agent を名指しした場合は、その agent を使う。

## 一覧

| Agent | 役割 | モデル |
|---|---|---|
| code-reviewer | 正しさ・変更スコープ・規約の横断レビュー。他に該当がない変更のフォールバック | opus |
| security-reviewer | 脆弱性（認証・認可、インジェクション、シークレット、入力検証、依存監査） | opus |
| python-reviewer | Python 固有の品質・型・FastAPI / Pydantic。ruff / 型チェック / pip-audit | opus |
| rust-reviewer | パニック要因・エラー処理・所有権・Tokio。cargo check / clippy / test | opus |
| frontend-reviewer | TypeScript / React / Next.js、a11y、Orval 生成コード。biome / tsc | opus |
| database-reviewer | スキーマ設計・クエリ・マイグレーション内容 | opus |
| api-spec-reviewer | エンドポイントの一貫性・認可の付け忘れ・後方互換性 | opus |
| refactor-cleaner | デッドコード・重複の検出（削除はしない） | opus |
| clean-arch-guard | import の依存方向とビジネスルール流出の機械的チェック | sonnet |
| migration-checker | モデル変更に対するマイグレーション漏れ | sonnet |
| test-runner | 関係するテストの実行と失敗分析 | sonnet |

## /rv の振り分け

どの変更でどの agent を起動するか、差分が小さいときに agent を使わず 1 パスで済ませる基準は `/rv` スキルに定義している（二重管理を避けるため、ここには書かない）。

## 出力の約束

レビュー系 agent はすべて次の 1 行形式で指摘を返す。/rv はこれをマージ・重複排除・検証してから報告する。

```
- [CRITICAL|HIGH|MEDIUM] path:line — 問題 → 修正案 (確信度: high|medium)
```

確信度がおおむね 80% 以上のものだけを返し、指摘が無ければ `指摘なし` と返す。

## /dev での利用

`/dev` では実装後にテストを実行し（失敗の分析が重いときは test-runner に任せる）、続けて `/rv` でセルフレビューする。
