# yuya-claude-code への貢献

このリポジトリは Claude Code のプラグインマーケットプレイスです。

---

## 貢献の流れ

### 1. ブランチを作成

```bash
git switch -c feat/your-feature-name
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
git commit -m "feat: 機能の説明"
git push -u origin feat/your-feature-name
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

## このリポジトリでの開発

このリポジトリの `.claude/` には、配布物から開発に必要なものを symlink で置いている。配布物を直すと、このリポジトリでの動作にもそのまま反映される。

| 種類 | 置いているもの |
|---|---|
| skills | `dev`, `rv`, `pr`, `sync`（`my-claude-code/skills/` への symlink） |
| agents | `code-reviewer`, `security-reviewer`（`my-claude-code/agents/` への symlink） |
| このリポジトリ専用 | `model-tune` — 新しいモデルや Claude Code の仕様変更に合わせて配布物を点検・修正する |

新しい Claude モデルが出たときや、Claude Code のスキル・agent・settings の仕様が変わったときは `/model-tune` を実行する。点検の記録は `.claude/skills/model-tune/history.md` に残る。

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
- スキル名は Claude Code の組み込みコマンド（`/init`, `/review`, `/code-review`, `/security-review` など）と被らせない
- レビュー系 agent を追加する場合は、`rules/agents.md` の統一出力フォーマットに従い、`/rv` の振り分け表（`skills/rv/SKILL.md`）にも追加する
- スキルや agent を廃止・改名した場合は、`install.sh` の `DEPRECATED_SKILLS` / `DEPRECATED_AGENTS` に旧名を追加する（`--prune` で利用側から片付けられるように）
