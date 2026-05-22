# Claude Code CLI 同梱イメージ

日本語化 n8n イメージ (`n8n-ja`) には、Claude Code CLI (`claude`) を任意で同梱できます。
これにより、n8n のワークフロー内（Execute Command ノード等）から `claude` を呼び出して
LLM 処理を組み込めます。

- 認証情報は**イメージに焼き込まず、実行時の環境変数で外だし**します。
- 認証 env が無い場合は**起動を拒否**します（誤って未認証で動かさない）。
- 同梱可否は**ビルド時のフラグ**で切り替えられます。

> 関連ファイル: [`Dockerfile.n8n-ja`](../Dockerfile.n8n-ja) / [`docker-compose.yml`](../docker-compose.yml) / [`.github/workflows/release-ja.yml`](../.github/workflows/release-ja.yml)

---

## 1. 同梱の仕組み

### ビルド時トグル

`Dockerfile.n8n-ja` の `ARG INSTALL_CLAUDE_CODE`（デフォルト `false`）で同梱可否を制御します。

| 値 | 挙動 |
|----|------|
| `false`（既定） | Claude Code CLI を**同梱しない**（標準の日本語化イメージ） |
| `true` | `claude` を同梱し、`/usr/local/bin/claude` にガードラッパーを設置 |

GitHub Releases で公開される `n8n-ja` イメージは、`release-ja.yml` が
`--build-arg INSTALL_CLAUDE_CODE=true` でビルドするため**同梱済み**です。

自前でビルドする場合:

```shell
docker build -f Dockerfile.n8n-ja \
  --build-arg N8N_VERSION=2.21.7 \
  --build-arg EDITOR_UI_ARCHIVE_URL="https://github.com/.../editor-ui.tar.gz" \
  --build-arg INSTALL_CLAUDE_CODE=true \
  -t n8n-ja:claude .
```

`CLAUDE_CODE_VERSION`（既定 `latest`）でバージョンを固定できます。

### 実行時ガード

同梱時、`/usr/local/bin/claude` は実体を直接呼ばず、次のラッパーになります。

- `ANTHROPIC_API_KEY` も `CLAUDE_CODE_OAUTH_TOKEN` も**未設定**ならメッセージを出して `exit 1`。
- どちらかが設定されていれば実体（`/usr/local/lib/claude-real`）を `exec` します。

ベースは Docker Hardened Image (Alpine) で、`node` / `npm` / `git` は同梱済み、
`ripgrep` は Claude Code 同梱の musl 版を使用します（追加パッケージ導入は不要）。

---

## 2. 認証の外だし

イメージにトークンを焼き込みません。**実行時に環境変数で渡します**。どちらか一方でOK。

| 方式 | 環境変数 | 取得方法 |
|------|----------|----------|
| API トークン | `ANTHROPIC_API_KEY` | Anthropic コンソールで発行 |
| サブスク (OAuth) | `CLAUDE_CODE_OAUTH_TOKEN` | ローカルで `claude setup-token` を実行して取得 |

### docker-compose での設定例

`docker-compose.yml`（`n8n-ja` イメージ使用時）:

```yaml
services:
  n8n:
    image: <your-dockerhub-user>/n8n-ja:latest-ja
    environment:
      - N8N_DEFAULT_LOCALE=ja
      # どちらか一方を .env で指定
      - CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN}
      # - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
```

`.env`:

```dotenv
CLAUDE_CODE_OAUTH_TOKEN=xxxxxxxx
# ANTHROPIC_API_KEY=sk-ant-xxxx
```

> `.env` は秘匿情報です。リポジトリにコミットしないでください。

---

## 3. n8n ワークフローから使う

LLM 呼び出しは **Execute Command ノード**で `claude` をヘッドレス実行します。

### 基本（テキスト生成）

ヘッドレスは `-p`（`--print`）。出力は JSON で受けると後処理が安全です。

```bash
claude -p "要約して: n8nとは何か" --output-format json --model claude-sonnet-4-6
```

後段の Code / Set ノードで本文を取り出します:

```js
// Code ノード
return [{ json: { result: JSON.parse($json.stdout).result } }];
```

### 動的プロンプト（シェルエスケープ必須）

n8n 式をそのまま文字列連結すると、引用符・改行で壊れたり**コマンドインジェクション**の
リスクがあります。`JSON.stringify` で安全に囲みます。

```
claude -p {{ JSON.stringify($json.prompt) }} --output-format json
```

長文・複雑な入力は一旦ファイルへ:

```bash
printf '%s' {{ JSON.stringify($json.prompt) }} > /tmp/p.txt \
  && claude -p "$(cat /tmp/p.txt)" --output-format json
```

### ツールを使わせる場合

ヘッドレスでは権限プロンプトを出せないため、許可を明示します
（テキスト生成だけなら不要）。

```bash
claude -p "..." \
  --allowedTools "Read,Write,Edit" \
  --permission-mode acceptEdits \
  --add-dir /data
```

### 出力フォーマット

| `--output-format` | 用途 |
|---|---|
| `text`（既定） | 素のテキスト |
| `json` | `{ result, ... }` の構造化（パース推奨） |
| `stream-json` | ストリーミング |

---

## 4. CLI を使わない選択肢

CLI にこだわらない場合、**HTTP Request ノードで Anthropic API を直接呼ぶ**方が
イメージが軽量で済みます（CLI 同梱不要、トークン管理のみ）。
ワークフロー内で 1〜数回の生成を行うだけならこちらが手軽です。

---

## 5. トラブルシューティング

| 症状 | 原因・対処 |
|------|-----------|
| `認証用 env ... が未設定のため起動しません` | `ANTHROPIC_API_KEY` または `CLAUDE_CODE_OAUTH_TOKEN` をコンテナ env に設定 |
| `Invalid API key` | `ANTHROPIC_API_KEY` の値が不正 |
| `401 Invalid bearer token` | `CLAUDE_CODE_OAUTH_TOKEN` が失効・不正。`claude setup-token` で再取得 |
| `claude: not found` | 標準イメージ（`INSTALL_CLAUDE_CODE=false`）を使用中。同梱ビルドのイメージを使う |
| ワークフローで引用符エラー | プロンプトを `JSON.stringify` で囲む（上記参照） |
