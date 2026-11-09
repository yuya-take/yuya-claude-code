# Agents

レビュー系の agent は `/rv` が変更内容に応じて振り分けて起動する。通常の会話や実装中に、指示なしでこれらの agent を自分から起動しない（サブエージェントの起動はコストと待ち時間がかかり、/rv の振り分けと重複するため）。ユーザーが特定の agent を名指しした場合は、その agent を使う。

## 一覧

| Agent | 役割 | モデル |
|---|---|---|
| code-reviewer | 正しさ・変更スコープ・規約の横断レビュー。他に該当がない変更のフォールバック | opus |
| security-reviewer | 脆弱性（認証・認可、インジェクション、シークレット、入力検証、依存監査） | opus |
| python-reviewer | Python 固有の品質・型・FastAPI / Pydantic、Clean Architecture のレイヤー違反。ruff / 型チェック / pip-audit | opus |
| rust-reviewer | パニック要因・エラー処理・所有権・Tokio。cargo check / clippy / fmt | opus |
| frontend-reviewer | TypeScript / React / Next.js、a11y、Orval 生成コード。biome / tsc | opus |
| database-reviewer | スキーマ設計・クエリ・マイグレーション内容と反映漏れ | opus |
| api-spec-reviewer | エンドポイントの一貫性・認可の付け忘れ・後方互換性 | opus |
| refactor-cleaner | デッドコード・重複の検出（削除はしない） | opus |
| test-runner | 関係するテストの実行と失敗分析（ユーザーが指示したときだけ使う） | sonnet |

## /rv の振り分け

どの変更でどの agent を起動するか、差分が小さいときに agent を使わず 1 パスで済ませる基準は `/rv` スキルに定義している（二重管理を避けるため、ここには書かない）。

## 出力の約束

レビュー系 agent はすべて次の 1 行形式で指摘を返す。/rv はこれをマージ・重複排除・検証してから報告する。

```
- [CRITICAL|HIGH|MEDIUM] path:line — 問題 → 修正案 (確信度: high|medium|low)
```

agent の役割は網羅で、確信が持てない指摘や重大度の低い指摘も確信度を付けてすべて返す。裏取りと絞り込みは /rv が行う（Opus 4.7 以降のモデルは「重要なものだけ報告」という指示に字義どおり従い、見つけたバグも報告しなくなるため）。指摘が無ければ `指摘なし` と返す。

## /dev での利用

`/dev` のテスト実行とセルフレビューは、サブエージェントを使わずにメインの流れで行う（自分の作業の検証をサブエージェントに任せると、同じ確認を二重に行うことになるため）。セルフレビューの観点には、上の agent 定義のチェック項目を使う。独立した複数観点のレビューは、ユーザーが `/rv` を実行したときに行う。
