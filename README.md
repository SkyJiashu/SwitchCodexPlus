# SwitchCodexPlus

**EN** | Seamlessly switch OpenAI Codex between official ChatGPT login and third-party API providers managed by [CC Switch](https://github.com/nicepkg/cc-switch), with [Codex++](https://github.com/nicepkg/aide) enhancements.

**中文** | 无缝切换 OpenAI Codex 的官方 ChatGPT 登录与第三方 API 服务商，配合 [CC Switch](https://github.com/nicepkg/cc-switch) 进行服务商管理，[Codex++](https://github.com/nicepkg/aide) 提供功能增强。

---

## Prerequisites / 前置条件

### For mode switching / 模式切换（核心功能）

| Tool / 工具 | Notes / 说明 |
|-------------|--------------|
| [OpenAI Codex](https://github.com/openai/codex) | Standard install is fine / 标准安装即可 |
| [CC Switch](https://github.com/nicepkg/cc-switch) | API provider manager / API 服务商管理器 |
| [Node.js](https://nodejs.org) LTS (v18+) | For SQLite access / 用于读取 SQLite |

### For launchers / 启动器（可选功能）

| Tool / 工具 | Notes / 说明 |
|-------------|--------------|
| [Codex++](https://github.com/nicepkg/aide) | Injects UI enhancements at launch / 启动时注入功能增强 |

> **Auto-detection / 自动检测**
>
> `setup.bat` detects your Codex installation automatically:
> - **CodexPatched** (`OpenAI\CodexPatched\`) — uses existing patched copy
> - **Standard Codex** (`OpenAI\Codex\`) — Codex++ will patch it in-place on first launcher run; originals are backed up automatically as `Codex.real.exe` and `app.asar.original`
>
> `setup.bat` 自动检测 Codex 安装，优先使用已有的 CodexPatched 副本，找不到时回落到标准 Codex 安装目录。使用启动器首次运行时，Codex++ 会自动在原目录就地打补丁，原始文件自动备份。

---

## Quick Start / 快速开始

```
1. Double-click setup.bat          双击运行 setup.bat
2. Switch-To-Api.bat               切换到 API 模式（由 CC Switch 管理服务商）
3. Switch-To-Official.bat          切换到官方 ChatGPT 登录
4. launchers\Start-Standard.bat    启动 Codex（标准模式）
```

`setup.bat` auto-detects your installations, installs `better-sqlite3`, and writes `config.ps1` with all paths resolved.

`setup.bat` 自动检测本机安装路径，安装 `better-sqlite3` 依赖，并生成包含所有路径的 `config.ps1`。

---

## File Structure / 文件结构

```
SwitchCodexPlus\
├── setup.bat                         ← Run once / 初次运行配置
├── setup.ps1                         ← Setup logic / 配置逻辑
├── config.ps1                        ← Auto-generated (gitignored) / 自动生成，不上传
│
├── Switch-To-Api.bat                 ← Switch to API mode / 切换到 API 模式
├── Switch-To-Official.bat            ← Switch to official login / 切换到官方登录
│
├── src\
│   ├── Switch-CodexMode.ps1          ← Core switching logic / 核心切换逻辑
│   ├── fix-ccswitch-providers.js     ← Patch CC Switch providers / 修补服务商配置
│   └── read-provider.js             ← Read CC Switch SQLite / 读取服务商数据
│
├── launchers\
│   ├── Start-Standard.bat            ← Launch Codex (standard) / 标准启动
│   ├── Start-Standard.ps1
│   ├── Start-ModelWhitelist.bat      ← Launch with model whitelist / 解锁模型白名单启动
│   └── Start-ModelWhitelist.ps1
│
├── state\official\                   ← Official config snapshot (gitignored) / 官方配置快照
└── backups\                          ← Timestamped backups (gitignored) / 时间戳备份
```

---

## How It Works / 工作原理

### API Mode (`Switch-To-Api.bat`)

**EN:**
1. Stops all Codex / Codex++ / CC Switch processes
2. Reads the active provider from CC Switch's SQLite database (`~/.cc-switch/cc-switch.db`)
3. Writes `~/.codex/auth.json` with the provider's API key
4. Patches `~/.codex/config.toml` — only `model_provider` and `[model_providers.*]` are replaced; all other settings (MCP servers, history, projects) are preserved
5. Injects `sandbox_mode = "danger-full-access"` + `approval_policy = "never"` so custom authorization rules appear in the UI
6. Runs `fix-ccswitch-providers.js` to patch any newly added providers automatically

After switching, you can change providers in CC Switch at any time — no need to re-run the script.

**中文：**
1. 停止所有 Codex / Codex++ / CC Switch 进程
2. 从 CC Switch 的 SQLite 数据库读取当前激活的服务商配置
3. 将服务商 API Key 写入 `~/.codex/auth.json`
4. 更新 `~/.codex/config.toml`——只替换 `model_provider` 和 `[model_providers.*]` 段落，其他配置（MCP、历史记录、项目信任）完整保留
5. 注入 `sandbox_mode = "danger-full-access"` + `approval_policy = "never"`，使自定义授权规则文件在 UI 中显示
6. 自动修补所有 CC Switch 服务商配置，新增服务商也能立即使用自定义授权

切换后可随时在 CC Switch 中换服务商，无需重新运行脚本。

---

### Official Mode (`Switch-To-Official.bat`)

**EN:** Restores the saved official config snapshot and ChatGPT auth tokens.

**中文：** 还原保存的官方配置快照和 ChatGPT 认证 token。

---

### Custom Authorization Rules / 自定义授权规则

**EN:** Codex natively offers three authorization modes. A custom rules file at `~/.codex/rules/default.rules` appears as an additional option **only when** `config.toml` contains:

**中文：** Codex 原生提供三种授权模式。位于 `~/.codex/rules/default.rules` 的自定义规则文件，**仅当** `config.toml` 包含以下两行时才会出现在 UI 中：

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

**EN:** `fix-ccswitch-providers.js` automatically injects these into every CC Switch provider's stored config, so all providers (including newly added ones) support custom authorization.

**中文：** `fix-ccswitch-providers.js` 会自动将这两行注入到所有 CC Switch 服务商的存储配置中，包括后续新增的服务商。

---

## CC Switch Data Structure / CC Switch 数据结构

CC Switch stores provider configs in SQLite at `~/.cc-switch/cc-switch.db`.  
CC Switch 将服务商配置存储在 `~/.cc-switch/cc-switch.db` 的 SQLite 数据库中。

```sql
SELECT id, name, settings_config FROM providers WHERE app_type = 'codex';
```

`settings_config` is a JSON field / `settings_config` 是一个 JSON 字段：

```json
{
  "auth": { "OPENAI_API_KEY": "sk-..." },
  "config": "model_provider = \"custom\"\n[model_providers.custom]\nname = \"My Provider\"\nbase_url = \"https://...\"\n..."
}
```

The active provider ID is stored in `~/.cc-switch/settings.json` → `currentProviderCodex`.  
当前激活的服务商 ID 存储在 `~/.cc-switch/settings.json` 的 `currentProviderCodex` 字段。

---

## Why Node.js for SQLite? / 为什么用 Node.js 读取 SQLite？

**EN:** PowerShell has no native SQLite driver; binary-parsing `.db` files is fragile. `better-sqlite3` provides reliable, typed access. Note: Codex's bundled `cua_node` (v24.14) is ABI-incompatible with precompiled `better-sqlite3` — this project uses the system Node.js install.

**中文：** PowerShell 没有原生 SQLite 驱动，直接二进制解析 `.db` 文件非常脆弱。`better-sqlite3` 提供可靠的类型化访问。注意：Codex 内置的 `cua_node`（v24.14）与预编译的 `better-sqlite3` 存在 ABI 不兼容，本项目使用系统 Node.js。

---

## Codex++ Feature Flags / Codex++ 功能开关

| Flag | Standard / 标准 | Model Whitelist / 白名单 | Description / 说明 |
|------|:--------------:|:------------------------:|-------------------|
| `codexAppServiceTierControls` | ✅ | ✅ | Speed selector / 速度选项 |
| `codexAppModelWhitelistUnlock` | ❌ | ✅ | More models / 解锁更多模型 |
| `codexAppConversationTimeline` | ✅ | ✅ | Timeline / 对话时间轴 |
| `codexAppSessionDelete` | ✅ | ✅ | Delete sessions / 删除会话 |
| `codexAppMarkdownExport` | ✅ | ✅ | Markdown export / 导出 MD |
| `providerSyncEnabled` | ❌ | ❌ | Disabled — prevents Codex++ overwriting API config / 禁用，防止覆写 API 配置 |
| `codexAppPluginMarketplaceUnlock` | ❌ | ❌ | Disabled — conflicts with patched asar / 禁用，与补丁冲突 |

---

## History Preservation / 历史记录保留

**EN:** Both modes set `history.persistence = "save-all"`. Conversation history is stored in SQLite under `~/.codex/` and is **never touched** by these scripts.

**中文：** 两种模式均设置 `history.persistence = "save-all"`。对话历史存储在 `~/.codex/` 下的 SQLite 数据库中，脚本**不会触碰**这些文件。

---

## License

MIT
