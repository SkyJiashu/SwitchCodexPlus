$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Write-Step([string]$msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK([string]$msg)   { Write-Host "    OK   $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "    WARN $msg" -ForegroundColor Yellow }
function Write-Fail([string]$msg) { Write-Host "    FAIL $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  SwitchCodexPlus Setup" -ForegroundColor White
Write-Host "  =====================" -ForegroundColor DarkGray

# ── 1. Detect Codex home ──────────────────────────────────────────────────────
Write-Step "Detecting Codex home (~/.codex)"
$CodexHome = Join-Path $env:USERPROFILE ".codex"
if (Test-Path $CodexHome) { Write-OK $CodexHome }
else { Write-Warn "~/.codex not found - Codex will create it on first launch: $CodexHome" }

# ── 2. Detect CC Switch ───────────────────────────────────────────────────────
Write-Step "Detecting CC Switch"
$CcSwitchDir      = Join-Path $env:USERPROFILE ".cc-switch"
$CcSwitchDb       = Join-Path $CcSwitchDir "cc-switch.db"
$CcSwitchSettings = Join-Path $CcSwitchDir "settings.json"
$HasCcSwitch      = Test-Path $CcSwitchDb
if ($HasCcSwitch) {
    Write-OK "DB:       $CcSwitchDb"
    Write-OK "Settings: $CcSwitchSettings"
} else {
    Write-Warn "CC Switch DB not found. Switcher scripts require CC Switch."
    Write-Warn "Install and launch CC Switch, then re-run setup.bat."
    Write-Warn "Expected: $CcSwitchDb"
}

# ── 3. Detect Codex++ (optional - required only for launchers) ────────────────
Write-Step "Detecting Codex++ (optional)"
$CodexPlusExe  = Join-Path $env:LOCALAPPDATA "Programs\Codex++\codex-plus-plus.exe"
$HasCodexPlus  = Test-Path $CodexPlusExe
if ($HasCodexPlus) { Write-OK $CodexPlusExe }
else {
    Write-Warn "Codex++ not found: $CodexPlusExe"
    Write-Warn "Switcher scripts work without Codex++."
    Write-Warn "Launcher scripts (Start-Standard / Start-ModelWhitelist) require Codex++."
}

# ── 4. Detect Codex++ session state dir ───────────────────────────────────────
$CodexSessionDir = Join-Path $env:USERPROFILE ".codex-session-delete"
if ($HasCodexPlus) {
    if (Test-Path $CodexSessionDir) { Write-OK "Session dir: $CodexSessionDir" }
    else { Write-Warn "Session dir not found (created by Codex++ on first launch): $CodexSessionDir" }
}

# ── 5. Detect Codex app (CodexPatched preferred, fallback to standard Codex) ──
Write-Step "Detecting Codex app"
$CodexAppPath    = $null
$CodexAppVariant = "none"

function Find-LatestCodexApp([string]$Root) {
    if (-not (Test-Path $Root)) { return $null }
    $latest = Get-ChildItem $Root -Directory |
        Where-Object { $_.Name -match '^Codex-' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) { return $null }
    $app = Join-Path $latest.FullName "app"
    if (Test-Path $app) { return [pscustomobject]@{ App = $app; Version = $latest.Name } }
    return $null
}

# Priority 1: CodexPatched (pre-patched copy, recommended)
$found = Find-LatestCodexApp (Join-Path $env:LOCALAPPDATA "OpenAI\CodexPatched")
if ($found) {
    $CodexAppPath    = $found.App
    $CodexAppVariant = "CodexPatched"
    Write-OK "CodexPatched: $CodexAppPath  ($($found.Version))"
    Write-Host "    Codex++ will use this pre-patched copy." -ForegroundColor DarkGray
}

# Priority 2: Standard Codex (Codex++ will patch in-place on first launch)
if (-not $CodexAppPath) {
    $found = Find-LatestCodexApp (Join-Path $env:LOCALAPPDATA "OpenAI\Codex")
    if ($found) {
        $CodexAppPath    = $found.App
        $CodexAppVariant = "Codex"
        Write-OK "Standard Codex: $CodexAppPath  ($($found.Version))"
        Write-Warn "Standard Codex detected. Codex++ will patch it in-place on first launcher run."
        Write-Warn "Original files are backed up automatically by Codex++ (Codex.real.exe, app.asar.original)."
    }
}

if (-not $CodexAppPath) {
    Write-Warn "No Codex installation found under %LOCALAPPDATA%\OpenAI\"
    Write-Warn "Launcher scripts will not work. Install Codex first, then re-run setup.bat."
    Write-Warn "Switcher scripts (Switch-To-Api / Switch-To-Official) are unaffected."
    $CodexAppPath    = ""
    $CodexAppVariant = "none"
}

# ── 6. Detect Node.js ─────────────────────────────────────────────────────────
Write-Step "Detecting Node.js"
$NodeExe    = $null
$candidates = @(
    "C:\Program Files\nodejs\node.exe",
    "C:\Program Files (x86)\nodejs\node.exe",
    (Get-Command node -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path $_) }
if ($candidates) {
    $NodeExe = $candidates[0]
    $nodeVer = & $NodeExe --version 2>&1
    Write-OK "$NodeExe  ($nodeVer)"
} else {
    Write-Fail "Node.js not found. Install from https://nodejs.org (LTS recommended)."
    throw "Node.js not installed."
}

# ── 7. Install better-sqlite3 ─────────────────────────────────────────────────
Write-Step "Installing better-sqlite3"
$Sqlite3Dir    = Join-Path $Root "node_modules\better-sqlite3"
$Sqlite3Binary = Join-Path $Sqlite3Dir "lib\index.js"
if (Test-Path $Sqlite3Binary) {
    Write-OK "Already installed: $Sqlite3Dir"
} else {
    Write-Host "    Running: npm install better-sqlite3 ..." -ForegroundColor DarkGray
    $npmCmd = Join-Path (Split-Path $NodeExe -Parent) "npm.cmd"
    if (-not (Test-Path $npmCmd)) { $npmCmd = "npm" }
    Push-Location $Root
    try {
        cmd /c "`"$npmCmd`" install better-sqlite3 --save-dev" 2>&1 |
            Where-Object { $_ -notmatch '^npm warn' } |
            ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        if (-not (Test-Path $Sqlite3Binary)) { throw "npm install completed but better-sqlite3 not found at: $Sqlite3Binary" }
        Write-OK "Installed: $Sqlite3Dir"
    } finally { Pop-Location }
}

# ── 8. Create runtime directories ─────────────────────────────────────────────
Write-Step "Creating runtime directories"
foreach ($d in @("state\official", "backups")) {
    $p = Join-Path $Root $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Write-OK $p
}

# ── 9. Write config.ps1 ───────────────────────────────────────────────────────
Write-Step "Writing config.ps1"
$configPath    = Join-Path $Root "config.ps1"
$configContent = @"
# Auto-generated by setup.ps1 - re-run setup.bat to update
# CodexAppVariant: '$CodexAppVariant'  (CodexPatched | Codex | none)
`$Config = @{
    CodexHome        = '$($CodexHome        -replace "'","''")'
    CcSwitchDb       = '$($CcSwitchDb       -replace "'","''")'
    CcSwitchSettings = '$($CcSwitchSettings  -replace "'","''")'
    NodeExe          = '$($NodeExe          -replace "'","''")'
    CodexPlusExe     = '$($CodexPlusExe     -replace "'","''")'
    CodexAppPath     = '$($CodexAppPath     -replace "'","''")'
    CodexAppVariant  = '$CodexAppVariant'
    CodexSessionDir  = '$($CodexSessionDir  -replace "'","''")'
}
"@
[System.IO.File]::WriteAllText($configPath, $configContent, [System.Text.UTF8Encoding]::new($false))
Write-OK $configPath

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Available features:" -ForegroundColor White

if ($HasCcSwitch) {
    Write-Host "    [OK] Switch-To-Api.bat      - switch to API mode (CC Switch manages provider)" -ForegroundColor Green
    Write-Host "    [OK] Switch-To-Official.bat - switch to official ChatGPT login" -ForegroundColor Green
} else {
    Write-Host "    [--] Switcher scripts need CC Switch (not detected)" -ForegroundColor Yellow
}

if ($HasCodexPlus -and $CodexAppVariant -ne "none") {
    Write-Host "    [OK] launchers\Start-Standard.bat       - launch Codex via Codex++" -ForegroundColor Green
    Write-Host "    [OK] launchers\Start-ModelWhitelist.bat - launch with model whitelist" -ForegroundColor Green
    if ($CodexAppVariant -eq "Codex") {
        Write-Host "         Note: first launch will patch your standard Codex installation." -ForegroundColor DarkGray
    }
} elseif (-not $HasCodexPlus) {
    Write-Host "    [--] Launcher scripts need Codex++ (not detected)" -ForegroundColor Yellow
} else {
    Write-Host "    [--] Launcher scripts need Codex installation (not detected)" -ForegroundColor Yellow
}

Write-Host ""
