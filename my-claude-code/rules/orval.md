---
paths:
  - "frontend/**/*.{ts,tsx}"
  - "frontend/orval.config.ts"
  - "backend/schema/openapi.json"
---

<!-- NOTE: パスはプロジェクト構成に合わせて読み替えてください。以下では frontend/, backend/ を使用しています。 -->

# Orval API Type Generation

## 概要

`frontend/app/lib/orval/` 以下のファイルはすべてOrvalによる自動生成。**手動で編集しないこと。**

## 生成ファイル

| パス | 内容 |
|---|---|
| `app/lib/orval/fastAPI.schemas.ts` | バックエンドAPIのTypeScript型定義（全スキーマ） |
| `app/lib/orval/{tag}/` | エンドポイントタグ別のTanStack Queryフック |

## 生成元

- **OpenAPI仕様**: `../backend/schema/openapi.json`（バックエンドが自動生成）
- **設定**: `orval.config.ts`
- **mutator**: `app/lib/orval/custom-fetch.ts` の `fetchJson` / `fetchBlob`

## 再生成手順

バックエンドAPIを変更した場合：

```bash
# 1. バックエンドのOpenAPIスキーマを更新
cd backend
make export-openapi

# 2. フロントエンドのコードを再生成
cd frontend
npm run generate-api  # orval実行 + Biomeフォーマット自動適用
```

## 注意事項

- `app/lib/orval/` 内の自動生成ファイルは `npm run generate-api` で上書きされる（`custom-fetch.ts` は手動管理）
- カスタマイズが必要な場合は `orval.config.ts` の `override` セクションを修正
- `fetchJson` は非2xxレスポンスで `ApiError` をthrowするため、生成フック内で追加のステータスコードチェックは不要
- CSV/ファイルダウンロード系エンドポイントは `fetchBlob` mutatorを使用（`orval.config.ts` の `operations` で設定）
