# mcp/

MCP サーバーのプラグインを置くディレクトリです（今は空です）。

## 追加手順

MCP サーバーは、単体のプラグインとして配布します。

1. `mcp/<server-name>/` を作り、`.claude-plugin/plugin.json` と `.mcp.json`（または plugin.json の `mcpServers` フィールド）を置きます。

   ```
   mcp/
   └── my-server/
       ├── .claude-plugin/
       │   └── plugin.json
       ├── .mcp.json          # MCP サーバーの定義
       └── src/               # サーバーの実装（必要なら）
   ```

2. ルートの `.claude-plugin/marketplace.json` の `plugins` に、エントリを追加します。

   ```json
   {
     "name": "my-server",
     "source": "./mcp/my-server",
     "description": "..."
   }
   ```

3. サーバーの起動コマンドの中のパスは、`${CLAUDE_PLUGIN_ROOT}` で参照します。プラグインはインストール時にキャッシュへコピーされるため、相対パスは使えません。

4. `claude plugin validate .` で検証してからコミットします。

既存の pack に同梱することもできます。ただ、MCP サーバーは有効・無効を個別に切り替えたいことが多いので、原則として 1 サーバー = 1 プラグインに分けます。
