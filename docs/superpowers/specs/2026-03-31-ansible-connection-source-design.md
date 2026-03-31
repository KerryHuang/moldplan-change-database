# 設計文件：Ansible 連線來源 + Specurai 路徑修正

**日期：** 2026-03-31
**範圍：** MoldplanDbSwitcher — 新增 Ansible 連線來源、修正 Specurai 路徑

---

## 背景

目前 app 支援兩個連線來源：

| 來源 | 路徑 | 問題 |
|------|------|------|
| TableSpec（舊名） | `%AppData%\TableSpec\connections.json` | 路徑與名稱已過時，應改為 Specurai |
| 自訂 | `%AppData%\MoldplanDbSwitcher\connections.json` | 正常 |

需求：
1. 修正 `TableSpec` → `Specurai`（路徑、UI、Source 值）
2. 新增第三個連線來源 `Ansible`，從 deploy-ansible 專案自動讀取每家客戶的正式/測試主資料庫連線

---

## 連線格式一致性

`Specurai`（`apps/DatabaseDescriptionApp`）與 `MoldplanDbSwitcher` 的 `connections.json` 格式相同（PascalCase JSON，`PropertyNameCaseInsensitive = true` 解析），兩者共用 `ConnectionProfile` 結構，無需轉換。

---

## 架構變更

### 新增元件

```
Models/
  AppSettings.cs                  → ansible repo 路徑、vault 密碼檔路徑

Services/
  IAppSettingsService.cs          → 讀寫 app-settings.json 介面
  AppSettingsService.cs           → 實作（建構式可注入 configDir）
  IAnsibleSyncService.cs          → 同步介面
  AnsibleSyncService.cs           → 讀取 deploy-ansible、解密 vault、產生連線

Views/
  SettingsDialog.axaml            → 新增設定視窗（ansible repo 路徑輸入）
  SettingsDialog.axaml.cs
```

### 修改元件

```
Services/ConnectionSourceService.cs   → 預設路徑 TableSpec → Specurai
Services/IConnectionSourceService.cs  → 方法名 LoadTableSpecConnections → LoadSpecuraiConnections
ViewModels/MainWindowViewModel.cs     → ShowTableSpec → ShowSpecurai、新增 ShowAnsible、SyncAnsibleCommand
Views/MainWindow.axaml                → 第三個 checkbox、同步按鈕、設定按鈕
```

---

## AppSettings 模型

```csharp
// Models/AppSettings.cs
public class AppSettings
{
    public string AnsibleRepoPath { get; set; } = string.Empty;

    // 預設 ~/.ansible-vault-pass（跨平台展開）
    public string VaultPasswordFile { get; set; } =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                     ".ansible-vault-pass");
}
```

儲存於：`%AppData%\MoldplanDbSwitcher\app-settings.json`

---

## AnsibleSyncService

### 讀取來源

deploy-ansible 目錄結構：

```
ansible/customer/inventory/
  hosts.yml                                   → mssql_host、tailscale_ip
  group_vars/
    all/database.yml                          → 全域預設
    customer_<name>/vault.yml                 → 客戶層密碼（加密）
    customer_<name>_production/database.yml   → 正式覆蓋
    customer_<name>_production/vault.yml      → 正式密碼（加密）
    customer_<name>_staging/database.yml      → 測試覆蓋
    customer_<name>_staging/vault.yml         → 測試密碼（加密）
```

### Vault 解密

純 .NET 實作（不依賴 ansible-vault CLI，跨平台可用）：

- 格式：`$ANSIBLE_VAULT;1.1;AES256`
- 演算法：PBKDF2-SHA256（10000 次）→ AES-256-CTR → PKCS7 去 padding
- 密碼來源：`VaultPasswordFile`（預設 `~/.ansible-vault-pass`）
- 密碼合併順序：`all/vault.yml` ← `customer_<name>/vault.yml` ← `customer_<name>_<env>/vault.yml`（後蓋前）

### 連線產生規則

| 條件 | Server | Username | Password |
|------|--------|----------|----------|
| `mssql_host = container` | `tailscale_ip` | `SA` | `vault_db_container_password` |
| `mssql_host = <IP>` | `mssql_host` | `mis` | `vault_db_main_password` 或 `vault_db_admin_password` |

密碼查找順序：`vault_db_main_password` → `vault_db_admin_password` → `vault_db_password` → `"service"`

### 連線命名

| Ansible 環境 | 顯示名稱 |
|---|---|
| `_production` | `{客戶名} - 正式` |
| `_staging` | `{客戶名} - 測試` |

客戶名：capitalize，例如 `junhe` → `Junhe`，`waydosoft01` → `Waydosoft01`

### Source 值

```csharp
profile.Source = "Ansible";
```

Ansible 連線為**唯讀**，不可在 UI 中編輯或刪除。

---

## UI 變更

### 主視窗

**連線來源 checkbox（由二改三）：**
```
連線來源：☑ Specurai  ☑ 自訂  ☑ Ansible
```

**功能列新增：**
- `[同步 Ansible]` 按鈕：未設定 `AnsibleRepoPath` 時 disabled
- `[設定]` 按鈕（或選單項）：開啟設定視窗

**同步行為：**
- 同步成功後更新記憶體中的 Ansible 連線清單並刷新 UI
- 同步中顯示 loading 狀態
- 失敗時顯示錯誤訊息（路徑不存在、vault 密碼錯誤等）

### 設定視窗

```
┌─ 設定 ──────────────────────────────────────┐
│                                              │
│  Ansible Repo 路徑：                         │
│  [_____________________________] [瀏覽...]   │
│                                              │
│  Vault 密碼檔案：                            │
│  [~/.ansible-vault-pass        ]             │
│                                              │
│                        [取消]  [儲存]        │
└──────────────────────────────────────────────┘
```

### 匯出/匯入

匯出對話框新增來源選擇：
```
匯出來源：☑ Specurai  ☑ 自訂  ☑ Ansible
```

---

## 不在範圍內

- Ansible 連線的編輯/新增/刪除（唯讀）
- MongoDB、Quartz、Hangfire 等非主資料庫連線
- 自動定時同步（手動點按鈕即可）

---

## TDD 範圍

| 測試類別 | 測試重點 |
|---|---|
| `AppSettingsServiceTests` | 讀寫 `app-settings.json`、預設值、configDir 注入 |
| `VaultDecryptorTests` | AES-256-CTR 解密正確性、HMAC 驗證、錯誤密碼拋例外 |
| `AnsibleSyncServiceTests` | 解析 database.yml、vault 合併、連線產生、container vs external 模式 |
| `ConnectionSourceServiceTests` | 路徑更新為 Specurai |
