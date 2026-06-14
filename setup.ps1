$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Write-Step([string]$msg) { Write-Host "`n>>> $msg" -ForegroundColor Cyan }
function Write-OK([string]$msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "    WARN $msg" -ForegroundColor Yellow }
function Write-Fail([string]$msg) { Write-Host "    FAIL $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  SwitchCodexPlus — Setup" -ForegroundColor White
Write-Host "  ========================" -ForegroundColor DarkGray

# ── 1. Detect Codex home ──────────────────────────────────────────────────────
Write-Step "Detecting Codex home (~/.codex)"
$CodexHome = Join-Path $env:USERPROFILE ".codex"
if (Test-Path $CodexHome) { Write-OK $CodexHome }
else {
    Write-Warn "~/.codex not found — will be created by Codex on first launch: $CodexHome"
}

# ── 2. Detect CC Switch ───────────────────────────────────────────────────────
Write-Step "Detecting CC Switch"
$CcSwitchDir      = Join-Path $env:USERPROFILE ".cc-switch"
$CcSwitchDb       = Join-Path $CcSwitchDir "cc-switch.db"
$CcSwitchSettings = Join-Path $CcSwitchDir "settings.json"
if (Test-Path $CcSwitchDb) {
    Write-OK "DB:       $CcSwitchDb"
    Write-OK "Settings: $CcSwitchSettings"
} else {
    Write-Warn "CC Switch DB not found. Install and launch CC Switch first."
    Write-Warn "Expected: $CcSwitchDb"
}

# ── 3. Detect Codex++ ─────────────────────────────────────────────────────────
Write-Step "Detecting Codex++"
$CodexPlusExe = Join-Path $env:LOCALAPPDATA "Programs\Codex++\codex-plus-plus.exe"
if (Test-Path $CodexPlusExe) { Write-OK $CodexPlusExe }
else {
    Write-Fail "Codex++ not found: $CodexPlusExe"
    Write-Host "    Install Codex++ then re-run setup.bat" -ForegroundColor Red
    throw "Codex++ not installed."
}

# ── 4. Detect Codex++ session state dir ───────────────────────────────────────
Write-Step "Detecting Codex++ session state"
$CodexSessionDir = Join-Path $env:USERPROFILE ".codex-session-delete"
if (Test-Path $CodexSessionDir) { Write-OK $CodexSessionDir }
else { Write-Warn "Session dir not found (Codex++ will create it on first launch): $CodexSessionDir" }

# ── 5. Detect CodexPatched ────────────────────────────────────────────────────
Write-Step "Detecting CodexPatched app"
$CodexPatchedApp = $null
$patchedRoot = Join-Path $env:LOCALAPPDATA "OpenAI\CodexPatched"
if (Test-Path $patchedRoot) {
    $latest = Get-ChildItem $patchedRoot -Directory |
        Where-Object { $_.Name -match '^Codex-' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($latest) {
        $CodexPatchedApp = Join-Path $latest.FullName "app"
        if (Test-Path $CodexPatchedApp) { Write-OK "$CodexPatchedApp  ($($latest.Name))" }
        else {
            Write-Warn "app subdir missing: $CodexPatchedApp"
            $CodexPatchedApp = $null
        }
    }
}
if (-not $CodexPatchedApp) {
    Write-Warn "CodexPatched not found under $patchedRoot"
    Write-Warn "Launcher scripts will not work without CodexPatched. Switcher scripts are unaffected."
    $CodexPatchedApp = "$patchedRoot\Codex-XX.XXX.XXXX.X\app"
}

# ── 6. Detect Node.js ────────────────────────────────────────────────────────
Write-Step "Detecting Node.js"
$NodeExe = $null
$candidates = @(
    "C:\Program Files\nodejs\node.exe",
    "C:\Program Files (x86)\nodejs\node.exe",
    (Get-Command node -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
) | Where-Object { $_ -and (Test-Path $_) }
if ($candidates) {
    $NodeExe = $candidates[0]
    $nodeVer = & $NodeExe --version 2>&1
    Write-OK "$NodeExe  ($nodeVer)"
} else {
    Write-Fail "Node.js not found. Install from https://nodejs.org (LTS recommended)."
    throw "Node.js not installed."
}

# ── 7. Install better-sqlite3 ────────────────────────────────────────────────
Write-Step "Installing better-sqlite3"
$NodeModulesDir  = Join-Path $Root "node_modules"
$Sqlite3Dir      = Join-Path $NodeModulesDir "better-sqlite3"
if (Test-Path $Sqlite3Dir) {
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
        if (-not (Test-Path $Sqlite3Dir)) { throw "npm install completed but better-sqlite3 not found." }
        Write-OK "Installed: $Sqlite3Dir"
    } finally { Pop-Location }
}

# ── 8. Create runtime directories ────────────────────────────────────────────
Write-Step "Creating runtime directories"
foreach ($d in @("state\official", "backups")) {
    $p = Join-Path $Root $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    Write-OK $p
}

# ── 9. Write config.ps1 ───────────────────────────────────────────────────────
Write-Step "Writing config.ps1"
$configPath = Join-Path $Root "config.ps1"
$configContent = @"
# Auto-generated by setup.ps1 — re-run setup.bat to update
`$Config = @{
    CodexHome        = '$($CodexHome       -replace "'","''")'
    CcSwitchDb       = '$($CcSwitchDb      -replace "'","''")'
    CcSwitchSettings = '$($CcSwitchSettings -replace "'","''")'
    NodeExe          = '$($NodeExe         -replace "'","''")'
    CodexPlusExe     = '$($CodexPlusExe    -replace "'","''")'
    CodexPatchedApp  = '$($CodexPatchedApp -replace "'","''")'
    CodexSessionDir  = '$($CodexSessionDir -replace "'","''")'
}
"@
[System.IO.File]::WriteAllText($configPath, $configContent, [System.Text.UTF8Encoding]::new($false))
Write-OK $configPath

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    Switch-To-Api.bat      — switch Codex to API mode (managed by CC Switch)"
Write-Host "    Switch-To-Official.bat — switch Codex to official ChatGPT login"
Write-Host "    launchers\Start-Standard.bat       — launch Codex (patched + Codex++)"
Write-Host "    launchers\Start-ModelWhitelist.bat — same + model whitelist unlocked"
Write-Host ""
