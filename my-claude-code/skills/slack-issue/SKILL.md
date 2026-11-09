---
name: slack-issue
description: Slackスレッドの内容からIssueを作成し、スレッドにリンクを投稿する。
argument-hint: "[SlackスレッドURL]"
disable-model-invocation: true
---

# Slack Issue

Slackスレッドの投稿内容を読み取り、Issueを作成して、元のスレッドにIssueリンクを投稿する。

## 引数の解析

`$ARGUMENTS` からSlackのスレッドURLを解析する。

URLフォーマット: `https://{workspace}.slack.com/archives/{channel_id}/p{timestamp}`

- `channel_id`: `/archives/` の直後のセグメント（例: `C0AQRPA3YTS`）
- `message_ts`: `p` の後の数値を `{先頭10桁}.{残り}` に変換（例: `p1775022933816269` → `1775022933.816269`）
- URL に `?thread_ts=...` が付いている場合（スレッド内の返信へのリンク）は、そちらが親メッセージの ts なので、スレッドの読み取りと投稿にはそれを使う

引数がない場合は「SlackスレッドのURLを指定してください」と案内して終了する。

## フロー

### Step 1: Slackスレッド読み取り

Slack の MCP ツール（スレッド読み取り用。例: `slack_read_thread`）でスレッドの内容を取得する。Slack のツールが使えない場合は、Slack MCP サーバー（または claude.ai の Slack コネクタ）の接続を案内して終了する。

### Step 2: コードベース調査

Slackの投稿内容から対象のサービス・機能を特定し、**コードベースを調査して原因分析と修正方針を導出する**。

1. **対象の特定**: 投稿内容のプロダクト名・画面名・機能名からコードの該当箇所を推定する
2. **コード調査**: Grep/Read/Glob等で関連するファイルを探索する
   - バックエンド: route → usecase → repository → model の流れを追う
   - フロントエンド: コンポーネント → hooks → API呼び出しの流れを追う
   - 投稿内容がバグ報告の場合は、正常系のフローを追って不具合箇所を特定する
3. **原因分析**: コードレベルで「なぜこの問題が起きるか」を特定する（ファイルパス・行番号付き）
4. **修正方針**: 具体的な修正手順を提案する（複数案がある場合はそれぞれのトレードオフも記載）

### Step 3: Issue内容の構成

スレッドの投稿内容とコード調査結果から以下を抽出・構成する:

- **タイトル**: `【{スコープ}】{内容の要約}` 形式（50文字以内目安）
  - スコープはプロダクト名・画面名等から判断（例: `backend`, `frontend`, `infra`）
- **ラベル**: 投稿内容から適切なラベルを選定
  - `gh label list` で確認
  - 種類ラベル: `feature`, `enhancement`, `bug` 等
  - サービスラベル: `frontend`, `backend` 等
- **本文**: 以下の構成で作成

```markdown
## 概要

{投稿内容を要約}

## 背景

{なぜこの変更が必要か}

## 原因分析

{コード調査で特定した原因をファイルパス・行番号・コードスニペット付きで記載}
{複数の原因がある場合は番号付きで列挙}

## 修正方針

{具体的な修正手順を記載}
{複数案がある場合はそれぞれのメリット・デメリットも記載}

## 参考

- Slack: {元のSlackスレッドURL}
```

### Step 4: ユーザー確認

作成するIssueのドラフトを提示する:

```
## Issue ドラフト

**タイトル**: {タイトル}
**ラベル**: {ラベル}

{Issue本文}

---
この内容でIssueを作成しますか？修正したい箇所があれば教えてください。
```

ドラフトには「作成後、元のスレッドに Issue のリンクを投稿する」ことも明記し、まとめて承認を得る。修正要望があれば反映して再提示する。

### Step 5: Issue作成

承認後、Issueを作成する:

```bash
gh issue create \
  --title "タイトル" \
  --label "label1,label2" \
  --body "$(cat <<'EOF'
Issue本文
EOF
)"
```

### Step 6: Slackスレッドに投稿

Slack の MCP ツール（メッセージ送信用。例: `slack_send_message`）で、元のスレッドに Issue のリンクを返信する:

- `channel_id`: Step 1 で使用したチャンネルID
- `thread_ts`: Step 1 で使用したメッセージタイムスタンプ
- メッセージ: `Issue作成しました :white_check_mark:\n{Issue URL}`

### Step 7: 完了報告

作成したIssue URLと、Slack投稿のリンクをユーザーに報告する。

## 注意事項

- ユーザーの承認なしに Issue の作成・Slack への投稿をしない
- Slackの投稿内容を忠実に反映する（勝手に要件を追加しない）
- スクリーンショット等の添付ファイルがある場合はその旨を本文に記載する
- ラベルは `gh label list` で存在を確認してから使う
