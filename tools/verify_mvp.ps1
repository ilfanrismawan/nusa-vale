param(
    [string]$GodotPath = 'E:\Godot\Godot.exe'
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot tidak ditemukan: $GodotPath" }
$auditPath = Join-Path ([System.IO.Path]::GetTempPath()) ('nusa-save-audit-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $auditPath | Out-Null
$previousAppData = $env:APPDATA
$previousAudit = $env:NUSA_SAVE_AUDIT

function Invoke-GodotCheck([string]$Label, [string[]]$Arguments, [bool]$ExpectedErrors = $false) {
    Write-Host $Label
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in (@('--headless', '--path', $projectPath) + $Arguments)) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill()
        throw "$Label timeout setelah 120 detik"
    }
    $output = ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()) -split "`r?`n"
    $exitCode = $process.ExitCode
    $process.Dispose()
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) { throw "$Label gagal (exit $exitCode)" }
    if (-not $ExpectedErrors -and ($output -match 'SCRIPT ERROR:|ERROR:')) {
        throw "$Label mengandung error Godot"
    }
    if ($ExpectedErrors -and -not ($output -match 'SAVE AUDIT COMPLETE: failures=0')) {
        throw 'Save audit tidak menyelesaikan semua pemeriksaan'
    }
}

try {
    # SaveManager auto-loads on startup: isolate every run from real player saves.
    $env:APPDATA = $auditPath
    $env:NUSA_SAVE_AUDIT = '1'
    Invoke-GodotCheck 'Editor/parser' @('--editor', '--quit')
    Invoke-GodotCheck 'Main menu' @('--quit-after', '60')
    foreach ($scene in @(
        'scenes/world/farm.tscn',
        'scenes/world/Forest.tscn',
        'scenes/world/town.tscn',
        'scenes/world/interior/interior_house.tscn',
        'scenes/world/interior/school.tscn',
        'scenes/world/interior/university.tscn'
    )) {
        Invoke-GodotCheck $scene @($scene, '--quit-after', '60')
    }
    Invoke-GodotCheck 'Co-op 2/3/4 players' @('tests/coop_smoke.tscn')
    Invoke-GodotCheck 'Save regression (expected I/O errors)' @('tests/save_regression.tscn') $true
    Write-Host 'MVP verification passed.'
} finally {
    $env:APPDATA = $previousAppData
    $env:NUSA_SAVE_AUDIT = $previousAudit
    Write-Host "Data uji terisolasi disimpan di: $auditPath"
}
