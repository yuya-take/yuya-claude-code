---
paths:
  - "**/frontend/**/*.{ts,tsx,js,jsx}"
---

# Frontend Development Standards

## Tech Stack

- **Framework**: Next.js 15+ with App Router
- **React**: Version 19.x
- **UI Components**: shadcn/ui component library
- **State Management**: Zustand (global state) + TanStack Query/SWR (server state)
- **Forms**: React Hook Form + Zod validation
- **Styling**: Tailwind CSS v4 (OKLCH color space)
- **Auth**: NextAuth.js（例: Cognito/Keycloak等のプロバイダー）

## Commands

- `npm run dev` - Start development server with Turbopack
- `npm run build` - Production build
- `npm run biome` - Run Biome lint + format (auto-fix)
- `npm run storybook` - Component development

## Biome (Linter/Formatter)

- ESLint / Prettier は使わない（Biome に統一している）
- Root `biome.json`: monorepo全体の共通設定
- 各サブプロジェクト `biome.json`: ルート設定を継承（`extends: "//"`）
- VS Code: Biome拡張をインストール（`.vscode/extensions.json`で推奨）
- 保存時の自動フォーマットが有効
