# yuya-claude-code

Claude Code の設定（skills / agents / rules / hooks / settings テンプレート）を配布するリポジトリ。

- `my-claude-code/` が配布物の本体。利用先には `install.sh`（`.claude/` へのコピー）か、プラグインとして入る
- `.claude/` はこのリポジトリ自身の開発用。`skills/` と `agents/` の大半は `my-claude-code/` への symlink で、配布物をそのまま使いながら開発する。`.claude/skills/model-tune/` だけはこのリポジトリ専用で、配布しない
- 配布物の文面は、利用先のプロジェクトで読まれる前提で書く。このリポジトリ固有の事情は配布物に書かない
- ベースブランチは `main`（`develop` は無い）。コミットメッセージは `<type>: <日本語の説明>`
- 配布物を変えたら `claude plugin validate .` を通す。スキルや agent を追加・削除・改名したときに合わせて直す箇所は CONTRIBUTING.md にある
