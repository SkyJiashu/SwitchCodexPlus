$ErrorActionPreference = "Stop"

# ── Load config ───────────────────────────────────────────────────────────────
$ConfigFile = Join-Path $PSScriptRoot "..\config.ps1"
if (-not (Test-Path -LiteralPath $ConfigFile)) {
    Write-Error "config.ps1 not found. Run setup.bat first.`n  Expected: $ConfigFile"
    exit 1
}
. $ConfigFile

$PatchedApp     = $Config.CodexAppPath
$PatchedExe     = Join-Path $PatchedApp "Codex.exe"
$PatchedRealExe = Join-Path $PatchedApp "Codex.real.exe"
$PatchedAsar    = Join-Path $PatchedApp "resources\app.asar"
$CodexPlus      = $Config.CodexPlusExe
$StateDir       = $Config.CodexSessionDir
$SettingsPath   = Join-Path $StateDir "settings.json"
$StatusPath     = Join-Path $StateDir "latest-status.json"
$DebugPort      = 9229
$HelperPort     = 57321

function Set-JsonProperty($Object, [string]$Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force }
}

function Write-Section([string]$Title) { Write-Host ""; Write-Host "=== $Title ===" }

function Show-ProcessSummary {
    Write-Section "Relevant processes"
    Get-CimInstance Win32_Process |
        Where-Object { $_.Name -ieq "Codex.exe" -or $_.Name -ieq "codex-plus-plus.exe" -or $_.Name -ieq "codex-plus-plus-manager.exe" } |
        Select-Object ProcessId, Name, ExecutablePath | Format-List
}

Write-Host "=== Codex++ Model Whitelist launcher ==="
Write-Host "App: $PatchedApp"

if (!(Test-Path -LiteralPath $PatchedExe))  { throw "Patched Codex.exe not found: $PatchedExe" }
if (!(Test-Path -LiteralPath $PatchedAsar)) { throw "Patched app.asar not found: $PatchedAsar" }
if (!(Test-Path -LiteralPath $CodexPlus))   { throw "Codex++ not found: $CodexPlus" }
if (!(Test-Path -LiteralPath $SettingsPath)) { throw "Codex++ settings not found: $SettingsPath" }

Write-Section "Saving Codex++ settings"
$backup = "$SettingsPath.bak-whitelist-$(Get-Date -Format yyyyMMddHHmmss)"
Copy-Item -LiteralPath $SettingsPath -Destination $backup -Force
$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json

Set-JsonProperty $settings "codexAppPath"                  $PatchedApp
Set-JsonProperty $settings "codexExtraArgs"                @()
Set-JsonProperty $settings "launchMode"                    "patch"
Set-JsonProperty $settings "enhancementsEnabled"           $true
Set-JsonProperty $settings "providerSyncEnabled"           $false
Set-JsonProperty $settings "codexAppPluginEntryUnlock"     $false
Set-JsonProperty $settings "codexAppPluginMarketplaceUnlock" $false
Set-JsonProperty $settings "codexAppForcePluginInstall"    $false
Set-JsonProperty $settings "codexAppModelWhitelistUnlock"  $true    # model whitelist ON
Set-JsonProperty $settings "codexAppServiceTierControls"   $true
Set-JsonProperty $settings "codexAppSessionDelete"         $true
Set-JsonProperty $settings "codexAppMarkdownExport"        $true
Set-JsonProperty $settings "codexAppProjectMove"           $false
Set-JsonProperty $settings "codexAppConversationTimeline"  $true
Set-JsonProperty $settings "codexAppConversationView"      $false
Set-JsonProperty $settings "codexAppThreadScrollRestore"   $true
Set-JsonProperty $settings "codexAppZedRemoteOpen"         $false
Set-JsonProperty $settings "codexAppUpstreamWorktreeCreate" $false
Set-JsonProperty $settings "codexAppNativeMenuPlacement"   $false
Set-JsonProperty $settings "codexGoalsEnabled"             $false

$settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
Write-Host "Backup: $backup"

Write-Section "Stopping existing processes"
Get-CimInstance Win32_Process |
    Where-Object { $_.Name -ieq "Codex.exe" -or $_.Name -ieq "codex-plus-plus.exe" -or $_.Name -ieq "codex-plus-plus-manager.exe" } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }
Start-Sleep -Seconds 2

if (Test-Path -LiteralPath $StatusPath) { Remove-Item -LiteralPath $StatusPath -Force -ErrorAction SilentlyContinue }
$LockDir = Join-Path $StateDir "locks"
if (Test-Path -LiteralPath $LockDir) {
    foreach ($lock in @("loopback-port-57320.lock","loopback-port-57321.lock","loopback-port-9229.lock")) {
        $lp = Join-Path $LockDir $lock
        if (Test-Path -LiteralPath $lp) { Remove-Item -LiteralPath $lp -Force -ErrorAction SilentlyContinue }
    }
}

Write-Section "Starting Codex++ (model whitelist enabled)"
$args = @("--app-path", $PatchedApp, "--debug-port", "$DebugPort", "--helper-port", "$HelperPort")
Start-Process -FilePath $CodexPlus -ArgumentList $args -WorkingDirectory (Split-Path -Parent $CodexPlus) | Out-Null
Write-Host "Waiting for startup..."
Start-Sleep -Seconds 10

Show-ProcessSummary

Write-Section "Result"
$listener = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $DebugPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
$actualPath = $null
if ($listener) {
    $actualPath = (Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)" -ErrorAction SilentlyContinue).ExecutablePath
}
if ($actualPath -and (($actualPath -ieq $PatchedExe) -or ($actualPath -ieq $PatchedRealExe))) {
    Write-Host "OK: patched Codex is running on debug port $DebugPort" -ForegroundColor Green
} else {
    Write-Host "WARN: debug port $DebugPort not owned by patched Codex" -ForegroundColor Yellow
    Write-Host "  Expected: $PatchedExe"
    Write-Host "  Actual:   $actualPath"
}
