---
name: dev
description: Issue（または自由記述のタスク）から開発環境を用意し、設計→実装→テスト→/rv セルフレビューまで進める開発ワークフロー。既定は Worktree で隔離、--branch でカレントリポジトリにブランチを切る。
disable-model-invocation: true
argument-hint: "<#番号 | Issue URL | タスク説明> [--branch] [--base <branch>] [--quick]"
effort: high
---

# /dev

引数: `$ARGUMENTS`

## 0. 引数の解釈

| 指定 | 意味 | 既定 |
|------|------|------|
| `#123` / `123` / Issue URL | Issue 駆動。`gh issue view <番号 or URL> --comments` で取得 | — |
| 上記以外の文字列 | Issue なしのタスク説明として扱う | — |
| `--branch` | Worktree を作らず、カレントリポジトリでブランチを切る | Worktree |
| `--base <branch>` | 分岐元ブランチ（例: エピックブランチから切る場合） | `develop`（無ければ `git symbolic-ref refs/remotes/origin/HEAD` のデフォルトブランチ） |
| `--quick` | Plan モードを省略し、計画を 3〜5 行で示してすぐ実装する（typo 修正や小さなバグ向け） | Plan あり |

引数が空なら、何を実装するかをユーザーに聞いて終了する。

## 1. 要件の把握

- Issue の場合: タイトル・本文・ラベル・コメントから、実装スコープと受け入れ条件を抜き出す。曖昧で実装方針が決まらない場合は `/issue-refine` を提案する
- タスク説明の場合: そのまま要件として扱い、不明点は Plan 段階で確認する

## 2. ブランチ名

`<type>/<issue番号>-<short-desc>`（Issue なしなら `<type>/<short-desc>`）。英語 kebab-case、50 文字以内。

type は内容から判断する: `feat` 新機能 / `fix` バグ修正 / `refactor` / `docs` / `chore` / `perf` / `test`

例: `feat/123-add-user-auth`, `fix/456-connection-timeout`, `chore/update-ci-cache`

## 3. 作業環境の準備

まず `git fetch origin <base>` で分岐元を最新にする。未コミットの変更がある状態で `--branch` を指定された場合は、続行してよいかを先に確認する（変更が新ブランチに持ち越されるため）。

### 既定: Worktree

分岐元とブランチ名を確実に指定するため、Worktree は git で作成してからセッションを移す（EnterWorktree の `name` 指定は分岐元を選べず、デフォルトブランチから切られる）。

```bash
git worktree add -b <branch> .claude/worktrees/<branch> origin/<base>
```

続けて EnterWorktree ツールに `path: .claude/worktrees/<branch>` を渡して移動する。ツールが使えない環境では `cd` で移動する。

Worktree は新しいチェックアウトなので、gitignore されたファイルは引き継がれない。

- **環境ファイル**: リポジトリルートに `.worktreeinclude` があれば、そこに書かれた gitignore 済みファイル（`.env` など）をメインの作業ツリーからコピーする。無ければ、テストや起動に必要な `.env*` があるかを確認し、コピーしてよいかをユーザーに確認する（`.worktreeinclude` は Claude Code が自分で作る Worktree にしか効かず、git で直接作った場合は手動でコピーする必要がある）
- **依存関係**: `node_modules` / `.venv` などは空なので、テストの前に `npm ci` / `uv sync` などを実行する

### `--branch`

```bash
git switch -c <branch> origin/<base>
```

## 4. 設計

`--quick` でなければ EnterPlanMode で Plan モードに入る。

- 調査範囲が広い（複数ディレクトリにまたがる、既存パターンを横断的に探す）場合は Explore サブエージェントに要件を渡し、「関連ファイル・該当箇所・既存実装の要点」だけを返してもらう。領域が独立していれば並列で起動してよい。既知のファイルを 1〜2 個読む程度なら直接読むほうが速い
- 計画には、変更するファイル、方針、テスト方針、影響範囲（API 互換性、マイグレーションの要否など）を含める
- ユーザーの承認を得てから ExitPlanMode する

## 5. 実装

- `.claude/rules/` の規約と、周辺コードの書き方に合わせる
- 振る舞いを変えたら、テストも追加・更新する
- 計画から外れる判断が必要になったら、実装を進める前にユーザーに相談する

## 6. 検証

- lint / format / 型チェック / テストを、プロジェクトのコマンド（`Makefile`、`package.json`、`pyproject.toml`、`Cargo.toml` を見て判断）で実行する
- 失敗したら原因を直して再実行する。失敗の原因分析が重い場合は `test-runner` エージェントに任せる
- 実行できなかった検証があれば、そのことを報告に明記する

## 7. セルフレビュー

Skill ツールで `rv`（プラグイン導入時は `my-claude-code:rv`）を `--base <base>` 付きで呼び、ブランチ差分（`origin/<base>` からの差分＋未コミット分）をレビューする。要件の充足確認のため、Issue の受け入れ条件もレビュアーに渡す。

CRITICAL と HIGH の指摘は修正してから報告する。MEDIUM は報告に載せ、直すかどうかはユーザーに任せる。

## 8. 完了報告

- 変更ファイルと実装サマリー
- 検証結果（実行したコマンドと結果）
- セルフレビューの結果（修正済みの指摘／残っている指摘）
- 次のステップ: `/pr` でコミット・PR 作成。Worktree の場合は、PR マージ後に `/sync` で片付けられることを伝える
