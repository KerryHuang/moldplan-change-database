---
name: pulling
description: Use when pulling from remote, syncing with upstream, or when user says "pull", "同步", "拉取", "更新". Also applies when user wants to get latest changes from remote.
---

# 拉取更新

## 步驟

### 1. 確認本地狀態

```bash
git status
```

若有未提交的變更，詢問使用者是否要先 commit 或 stash，再繼續：
- commit → 執行 `/committing`
- stash → 執行 `git stash`，pull 完後執行 `git stash pop`

### 2. 執行 pull

```bash
git pull
```

### 3. 更新子模組（若有）

本專案含 `apps/DatabaseDescriptionApp` 子模組，pull 後需同步：

```bash
git submodule update --init --recursive
```

### 4. 顯示變更摘要

```bash
git log --oneline ORIG_HEAD..HEAD 2>/dev/null || echo "（無新 commit）"
```

列出此次拉取帶入的新 commit，讓使用者了解有哪些變更。

### 5. 回報結果

說明拉取了幾個新 commit，子模組是否有更新，以及是否需要重新建置（`dotnet build`）。
