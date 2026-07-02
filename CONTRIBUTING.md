# yuya-claude-code への貢献

このリポジトリは Claude Code のプラグインマーケットプレイスです。

---

## 貢献の流れ

### 1. ブランチを作成

```bash
git checkout -b feature/your-feature-name
```

### 2. ファイルを追加・編集

適切なディレクトリに配置してください：

- `my-claude-code/agents/` — サブエージェント定義
- `my-claude-code/skills/` — ワークフロー定義 (`skills/<name>/SKILL.md`)
- `my-claude-code/hooks/` — フック処理スクリプト (`hooks.json` に登録)
- `my-claude-code/rules/` — 常時適用ガイドライン (`/my-claude-code:setup` で展開)
- `my-claude-code/templates/` — `.claude/` に展開するテンプレート (settings.json 等)
- `mcp/` — MCP サーバープラグイン ([mcp/README.md](mcp/README.md) 参照)

新しいプラグインを追加する場合は、ルートの `.claude-plugin/marketplace.json` にエントリを追加してください。

### 3. 検証・テスト

```bash
claude plugin validate .
```

ローカルマーケットプレイスとして追加して動作確認：

```shell
/plugin marketplace add ./path/to/yuya-claude-code
/plugin install my-claude-code@yuya-claude-code
```

rules を変更した場合は、実際のプロジェクトの `.claude/` にコピーして確認してください。

### 4. PR を作成

```bash
git add .
git commit -m "Add: 機能の説明"
git push origin feature/your-feature-name
```

---

## ファイル形式

### Agents

```markdown
---
name: agent-name
description: 説明
tools: Read, Grep, Glob
model: sonnet
---

指示内容...
```

### Skills

`my-claude-code/skills/<skill-name>/SKILL.md` に配置：

```markdown
---
name: skill-name
description: 説明
---

指示内容...
```

### Rules

```markdown
# ルール名

ガイドライン内容...
```

---

## 変更時の作業

- Agents / Skills / Hooks / Rules を変更した場合: コミットするだけで配布される（バージョンは git コミット SHA ベース）
- Rules の変更は利用側で `/my-claude-code:setup` を再実行すると反映される

---

## ガイドライン

- 設定はシンプルに保つ
- 説明を含める
- 提出前にテストする
- 既存のパターンに従う
- API キーなどの機密情報を含めない
- 実プロジェクトで動作確認済みのものを優先
