# Claude Code 向け プロジェクト指示

このリポジトリで作業する際の Claude Code 専用ガイドです。詳細は [`.github/Skills.md`](.github/Skills.md) を参照してください（`AGENTS.md` / `.github/copilot-instructions.md` と内容を共有する canonical ソース）。

## 必読

- 本ファイル
- [`.github/Skills.md`](.github/Skills.md)
- [`README.md`](README.md)

## ハードルール

- 会話・コミットメッセージ・PR 本文は **日本語**。コード内識別子・コメントは **英語**。
- `main` / `master` / `Release` への直接コミット禁止。必ず作業ブランチを切る。
- コミットメッセージはプレフィックス付き: `feat:` / `fix:` / `chore:` / `docs:` / `refactor:` / `test:` / `ci:` / `style:` / `perf:`。
- プッシュ前にブランチの作業コミットは可能なら 1 つに squash する。
- `languages/**` および `script/en.json` は機械翻訳フロー以外で変更しない。
- 認証情報（Anthropic API キー / Docker Hub トークン / OAuth トークン）をリポジトリにコミットしない。`secrets.*` / 実行時 env のみ。

## 推奨パターン

- 翻訳の生成・更新は [`script/translate.js`](script/translate.js) と jq の組み合わせで決定論的処理 + LLM の差分翻訳という分業を守る。
- 自動 PR は `auto-heal/*` または `auto/n8n-*-ja` ブランチ名 + 対応ラベル（`auto-heal` / `automated` / `n8n-update`）を付ける。Copilot レビュー駆動の自動マージ／自動修正が走るのはこの規約に従う PR のみ。
- Branch protection の必須 status check 名（`yaml-workflow-lint` / `format-check` / `n8n-smoke-test`）を変更したら `.github/Skills.md` の ruleset セクションも更新する。

## やりがちな落とし穴

- `gh pr merge` は `--auto` を付けないと Branch protection で即失敗する。即マージしたい場合のみ `--admin`（権限がある場合）。
- `claude-code-action` を `issue_comment` 起点で動かすときは **default branch (main) の YAML が読まれる**。PR ブランチ上で workflow を編集しても次の発火に反映されない。
- 翻訳 PR は `languages/ja.json` の差分が巨大化しがち。LLM レビューに丸投げせず、キー単位の前処理を入れる。

## より詳しい知識

- ワークフロー構成、Copilot レビュー contract、命名規約: [`.github/Skills.md`](.github/Skills.md)
- フォーク元との違い: [`docs/fork-differences.md`](docs/fork-differences.md)
- Claude Code CLI 同梱イメージ: [`docs/claude-code-cli.md`](docs/claude-code-cli.md)
