---
name: mr
description: Merge Request / Pull Request を作成する。ブランチ確認・作成、差分確認、コミット分割、プッシュ、MR/PR作成/更新まで一連のワークフロー。
disable-model-invocation: true
---

以下の手順でブランチ作成からMR/PR対応まで行ってください。

> **CLI の使い分け**: `git remote get-url origin` が `github.com` を含むなら `gh`（PR）、それ以外なら `glab`（MR）を使う。

## 1. ブランチ確認・作成
- `git branch --show-current` で現在のブランチを確認
- **developブランチの場合**: 変更内容を確認し、適切なブランチ名で `git checkout -b ブランチ名` を実行
- **すでに変更に対応するブランチの場合**: ブランチ作成はスキップしてそのまま進める

## 2. 差分確認
- `git status` で変更ファイル一覧を確認
- `git diff` で具体的な変更内容を確認
- 変更内容を把握した上で次に進む

## 3. コミット
- 変更内容に応じてコミットをわかりやすく分割する
- 各コミットメッセージは変更内容が明確にわかるようにする
- 例: 機能追加、リファクタ、バグ修正などは分けてコミット

## 4. プッシュ
- `git push -u origin ブランチ名` でリモートにプッシュ

## 5. MR/PR確認・作成
- `glab mr list`（GitHub: `gh pr list`）で現在のブランチに対応するMR/PRがあるか確認
- **ない場合**: `glab mr create`（GitHub: `gh pr create`）で作成
- **ある場合**: `glab mr view`（GitHub: `gh pr view`）で内容を確認し、descriptionに修正が必要であれば `glab mr update`（GitHub: `gh pr edit`）で更新

## 注意事項
- コミットは論理的な単位で分割すること
- MR/PRのdescriptionには変更内容の概要を記載すること
