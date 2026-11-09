# mcp/

将来追加する MCP サーバー用のディレクトリ。

## 追加手順

MCP サーバーは単体のプラグインとして配布する。

1. `mcp/<server-name>/` を作成し、`.claude-plugin/plugin.json` と `.mcp.json`（または plugin.json 内の `mcpServers` フィールド）を置く

   ```
   mcp/
   └── my-server/
       ├── .claude-plugin/
       │   └── plugin.json
       ├── .mcp.json          # MCP サーバー定義
       └── src/               # サーバー実装（必要なら）
   ```

2. ルートの `.claude-plugin/marketplace.json` の `plugins` にエントリを追加する

   ```json
   {
     "name": "my-server",
     "source": "./mcp/my-server",
     "description": "..."
   }
   ```

3. サーバー起動コマンド内のパスは `${CLAUDE_PLUGIN_ROOT}` で参照する（プラグインはインストール時にキャッシュへコピーされるため、相対パスは使えない）

4. `claude plugin validate .` で検証してからコミットする

既存の pack に同梱することもできるが、MCP サーバーは有効/無効を個別に切り替えたいことが多いので、原則 1 サーバー = 1 プラグインで分ける。
