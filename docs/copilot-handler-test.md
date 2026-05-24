# Copilot レビュー後の自動マージ / 自動修正ワークフロー動作確認

このファイルは `.github/workflows/copilot-review-handler.yml` の動作確認用のダミードキュメントです。

## 検証項目

- [ ] `auto-heal/*` ブランチ + `auto-heal` ラベルで `triage` ジョブが通る
- [ ] Jenkins からの `VERDICT: APPROVE` コメントで `auto-merge` ジョブが発火
- [ ] `VERDICT: REQUEST_CHANGES` コメントで `auto-fix` ジョブが発火
- [ ] 5 回ループで `give-up` ジョブが発火し `needs-human-review` ラベルが付与される
- [ ] 非対象ラベル / 非対象ブランチ / 非 bot コメントが `triage` で skip される

検証完了後にこのファイルは削除する。
