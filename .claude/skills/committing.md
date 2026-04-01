---
name: committing
description: Use when committing changes, staging files, or when user says "commit", "提交", "存檔". Also applies when user asks to save work or create a checkpoint.
---

# 提交變更

## 步驟

### 1. 確認目前狀態

```bash
git status
git diff --staged
git diff
```

### 2. 確認測試通過（Law 2: TDD）

若有未執行的測試，先執行：

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/
```

測試失敗則停止，不得在測試失敗時 commit。

### 3. 確認 staged 內容

若有變更但尚未 stage，根據 `git status` 輸出列出建議的檔案，請使用者確認後再執行 `git add <file>`。
不得使用 `git add -A` 或 `git add .`。

### 4. 撰寫 commit 訊息

**格式：** `<type>: <繁體中文說明>`

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修正 bug |
| `refactor` | 重構（不改行為） |
| `test` | 新增或修改測試 |
| `chore` | 建置、設定、文件 |

提案 commit 訊息給使用者確認後再執行。

### 5. 執行 commit

```bash
git commit -m "$(cat <<'EOF'
<type>: <說明>
EOF
)"
```

### 6. 回報結果

顯示 commit hash 與訊息，提醒是否需要接著 push（`/pushing`）。
