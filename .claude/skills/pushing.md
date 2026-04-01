---
name: pushing
description: Use when pushing to remote, releasing a new version, or when user says "push", "發版", "推送", "release". Also applies when user asks why CI did not trigger after a push.
---

# 推送與發版

推送前確認版本 tag，確保 CI release pipeline 被觸發。

## 步驟

### 1. 確認當前狀態

執行以下指令，一次取得所需資訊：

```bash
git log --oneline -5
git tag -l | sort -V | tail -5
git describe --tags --exact-match HEAD 2>/dev/null || echo "NO_TAG"
```

### 2. 判斷是否需要 tag

**若 HEAD 已有 tag：**
直接執行步驟 4，不需詢問版本號。

**若 HEAD 沒有 tag（輸出為 `NO_TAG`）：**
告知使用者目前最新 tag 與未打標的 commit 數量，詢問：

> 目前最新 tag 是 `vX.X.X`，有 N 個 commit 尚未標版本。
> 請問要建立新 tag 嗎？版本號建議為 `vX.X.Y`（或請輸入你想要的版本號）

等待使用者確認或提供版本號。若使用者不想建立 tag，直接執行 `git push` 並提醒不會觸發 release。

### 3. 建立 tag

```bash
git tag <version>
```

### 4. 推送（含 tag）

```bash
git push --follow-tags
```

### 5. 回報結果

告知推送成功，並說明是否觸發了 release pipeline（有 tag = 會觸發）。
