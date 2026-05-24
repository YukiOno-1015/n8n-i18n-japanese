# Agent 向け プロジェクト指示

[AGENTS.md spec](https://agents.md) に従う、コードエージェント共通の指示ファイルです。

詳細は [`.github/Skills.md`](.github/Skills.md) を参照してください（canonical ソース）。Claude Code 専用の補足は [`CLAUDE.md`](CLAUDE.md)、GitHub Copilot 専用の補足は [`.github/copilot-instructions.md`](.github/copilot-instructions.md) を参照してください。

## このリポジトリは何か

n8n の UI を日本語化し、翻訳済み `editor-ui` と `n8n-ja` Docker イメージとして配布するプロジェクトです。

- 翻訳ファイル: [`languages/ja.json`](languages/ja.json)
- 翻訳スクリプト: [`script/translate.js`](script/translate.js)
- 配布イメージ: [`Dockerfile.n8n-ja`](Dockerfile.n8n-ja)
- CI/CD: [`.github/workflows/`](.github/workflows/)

## エージェントが守るルール

### 言語

- 会話・コミットメッセージ・PR 本文 → **日本語**
- コード内識別子・コメント → **英語**

### Git

- `main` / `master` / `Release` に直接コミット禁止。作業ブランチを切る。
- コミットメッセージは `<type>: <日本語の説明>`。type は `feat` / `fix` / `chore` / `docs` / `refactor` / `test` / `ci` / `style` / `perf`。
- プッシュ前に作業コミットを 1 つに squash することを推奨。
- 既にリモートへプッシュ済みのブランチを書き換えるとき（force push / rebase）は、事前にユーザーへ可否を確認する。

### 変更スコープ

- 依頼と無関係なフォーマット変更や一括整形はしない。
- `languages/**` および `script/en.json` は翻訳フロー以外で書き換えない。
- 新しい依存を追加する前に、既存依存で済まないか確認する。

### Secrets / 認証

- Anthropic API キー / Docker Hub トークン / OAuth トークン等をコミットしない。
- Docker イメージにも焼き込まず、実行時 env で外だし。

### 自動 PR の規約

| 項目 | 値 |
|------|----|
| ブランチ命名 | `auto-heal/*` または `auto/n8n-*-ja` |
| ラベル | `auto-heal` / `automated` / `n8n-update` のいずれか |
| マージ方式 | squash |
| 必須 status check | `yaml-workflow-lint` / `format-check` / `n8n-smoke-test` |

詳細は [`.github/Skills.md`](.github/Skills.md) を参照。

## ローカル開発

```shell
npm install
npm run i18n:translate    # 差分翻訳実行（OPENAI/GEMINI API キー必要）
docker compose up         # editor-ui-dist を配置して n8n 起動
```

詳細は [`README.md`](README.md) を参照。
