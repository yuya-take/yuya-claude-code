# /model-tune の記録

新しい記録を先頭に追加する。

## 2026-11-10 — `/dev` の Plan モードを廃止（Claude Opus 5.5）

**参照した公式情報**
- `claude-api` スキル同梱の `shared/model-migration.md`（Migrating to Claude Opus 5.5、Migrating to Claude Opus 5 → Capability improvements の Agentic coding と Behavioral shifts の Task scope expansion）と `shared/prompt-audit.md`（「plan before acting」は削除対象）
- https://code.claude.com/docs/en/best-practices.md 、permission-modes.md 、goal.md

**判断の根拠**
- Opus 5 系は、タスクの仕様を最初にまとめて渡し、そのまま走らせると最も強い。途中で承認を挟むと、対話の往復が増えて効率も性能も落ちる
- 今のモデルは指示しなくても計画を立て、「先に計画せよ」は計画のしすぎを招く
- Claude Code のベストプラクティスは Plan モードを手順として挙げていない。勧めているのは、完了の条件を最初に書くこと、要件が固まっていなければ先に仕様を詰めること、合否の出るチェックを渡すこと
- 一方で、頼まれていない範囲まで作業を広げる傾向があるので、解釈によって作業が大きく変わるときだけ確認する指示は残す

**反映した変更**
- `/dev` は計画を示したらそのまま実装する。承認を待つのは `--plan` 指定時、取り消しにくい変更（DB スキーマ・公開 API の互換性・データの削除や移行）、Issue の範囲を超える変更、オーケストレータ配下モードのときだけ
- 要件の把握の段階で完了の条件（受け入れ条件と通すチェック）を決め、検証ではそれが通るまで直す
- `--quick` を廃止（既定の動きになった）

## 2026-11-09 — Claude Opus 5.5 / Claude Code 2.1.319

**参照した公式情報**
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5
- `claude-api` スキル同梱の `shared/model-migration.md`（Migrating to Claude Opus 5.5、Migrating to Claude Opus 5 → Behavioral shifts、Opus 4.7 → Code review）と `shared/prompt-audit.md`
- https://code.claude.com/docs/en/skills.md 、sub-agents.md 、model-config.md 、settings-reference.md 、worktrees.md

**モデルプロファイル**
- 思考は常にオン。effort が唯一の制御で、既定は `medium`（Opus 5 の `high` 以上の性能）。`xhigh` / `max` は効果を測れた作業だけに使う
- コードレビューに強い（見つけるバグが多く、誤検知が少ない）。一方で「重要なものだけ報告」という指示には字義どおり従い、見落としが増える
- サブエージェントを積極的に使う傾向がある（Opus 5 から）。レビュー・検証・見直しにはサブエージェントを使わず、メインの流れで行うのが推奨
- 長い作業の途中で、経過報告だけを書いてターンを終えることがある
- Claude Code: スキルの `effort` はそのターンのセッション設定を上書きする。メインと別のモデルで動くサブエージェントには、セッションの effort が適用されない。`attribution` を `false` にする書き方は v2.1.281 以降でしか読めない

**反映した変更**（PR #2）
- reviewer は確信度（high / medium / low）付きで網羅的に返し、絞り込みは `/rv` の裏取り段階で行う
- `/dev` のセルフレビューとテストの失敗分析を、サブエージェントなしでメインの流れで行う
- 常にセットで起動していた agent を統合（`clean-arch-guard` → `python-reviewer`、`migration-checker` → `database-reviewer`）。`/rv` の同一 agent の分割起動をやめる
- `/dev`・`/rv` の `effort: high` を削除。`test-runner` に `effort: medium`
- `/dev` に、計画承認後に止まってよい場面を明記
- 強調表現・圧力表現の削除、組み込みコマンド（`/init`, `/code-review`, `/security-review`）との名前衝突の解消
