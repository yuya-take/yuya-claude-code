---
name: troubleshooting
description: サービスのトラブルシューティングガイド。サービス起動失敗、DB接続エラー、マイグレーション問題、ポート競合の解決手順。エラーやインフラ問題が発生した際に使用。
user-invocable: false
---

# Common Troubleshooting

以下のコマンドはプロジェクトの例（`/setup` で実際のものに置き換える）。データを消すコマンド（ボリューム削除、downgrade など）は、実行前にユーザーに確認する。

## Service Won't Start

```bash
# サービス状態とログを確認（例: プロジェクトの Makefile に合わせて変更）
make infra-status                     # 例: インフラ状態確認
make infra-logs                       # 例: ログ確認

# 環境変数の検証
make env-check ENV=local              # 例: 必要な環境変数が設定されているか確認

# サービス再起動（例: プロジェクトの Makefile に合わせて変更）
make infra-stop                       # 例: インフラ停止
make infra-local                      # 例: ローカルインフラ起動

# Docker状態確認
docker system df          # ディスク容量確認
docker compose ps         # コンテナ状態確認
```

## Database Connection Issues

```bash
# RDB_HOST設定を確認
# - ホスト起動パターン（.env.local）: RDB_HOST=localhost
# - コンテナ結合パターン（.env.local-full）: RDB_HOST=project-master-db

# 環境変数ファイルの再配布（例: プロジェクトの Makefile に合わせて変更）
make setup-local                      # 例: ローカル環境セットアップ

# ボリューム削除して再起動（データは消えます）
make infra-stop-volume                # 例: ボリューム付きインフラ停止
make infra-local                      # 例: ローカルインフラ起動

# マイグレーション適用（例: プロジェクトのマイグレーションディレクトリに合わせて変更）
# cd infrastructure/migrations
# make upgrade
```

## Migration Issues

```bash
# 以下はプロジェクトのマイグレーションツールに合わせて変更してください
# Check current migration status（例）
cd infrastructure/migrations
make current

# Reset to specific revision（例）
make downgrade  # One step back

# Generate migration after model changes（例）
make migration MSG="description"
```

## Port Conflicts

```bash
# Check specific port usage（例: ポート番号はプロジェクトに合わせて変更）
lsof -nP -iTCP:8000 -sTCP:LISTEN  # 例: バックエンドサービス
lsof -nP -iTCP:3000 -sTCP:LISTEN  # 例: フロントエンド（Linux なら ss -ltnp | grep :3000 でも可）

# Stop conflicting services or use different ports
```
