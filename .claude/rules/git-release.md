# Git Release 慣例

- Push 時必須同時推送 tag 才會觸發 CI release pipeline
- Tag 格式：`v{major}.{minor}.{patch}`，例如 `v1.2.3`
- 推送指令：`git push && git push --tags`，或合併為 `git push --follow-tags`
- 建立 tag 前先確認使用者想要的版本號
