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

	$allArguments = @('--headless', '--path', $projectPath) + $Arguments

	if ($PSVersionTable.PSVersion.Major -ge 7) {
		foreach ($argument in $allArguments) {
			$startInfo.ArgumentList.Add($argument)
		}
	}
	else {
		# Compatibility with Windows PowerShell 5.1
		$quotedArguments = foreach ($argument in $allArguments) {
			$escaped = $argument -replace '(\\*)"', '$1$1\"'
			$escaped = $escaped -replace '(\\+)$', '$1$1'
			'"' + $escaped + '"'
		}

		$startInfo.Arguments = $quotedArguments -join ' '
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
    if ($output -match 'SCRIPT ERROR:|FAIL:') {
        throw "$Label mengandung kegagalan script atau assertion"
    }
    if (-not $ExpectedErrors -and ($output -match 'SCRIPT ERROR:|ERROR:')) {
        throw "$Label mengandung error Godot"
    }
    if ($ExpectedErrors -and $Arguments -contains 'tests/save_regression.tscn' -and -not ($output -match 'SAVE AUDIT COMPLETE: failures=0')) {
        throw 'Save audit tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/coop_smoke.tscn' -and -not ($output -match 'COOP SMOKE COMPLETE: failures=0')) {
        throw 'Co-op smoke tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/gameplay_regression.tscn' -and -not ($output -match 'GAMEPLAY REGRESSION COMPLETE: failures=0')) {
        throw 'Gameplay regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/tool_progression_regression.tscn' -and -not ($output -match 'TOOL PROGRESSION COMPLETE: failures=0')) {
        throw 'Tool progression regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/crop_regression.tscn' -and -not ($output -match 'CROP REGRESSION COMPLETE: failures=0')) {
        throw 'Crop regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/menu_regression.tscn' -and -not ($output -match 'MENU REGRESSION COMPLETE: failures=0')) {
        throw 'Menu regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/crafting_regression.tscn' -and -not ($output -match 'CRAFTING REGRESSION COMPLETE: failures=0')) {
        throw 'Crafting regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/structure_regression.tscn' -and -not ($output -match 'STRUCTURE REGRESSION COMPLETE: failures=0')) {
        throw 'Structure regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/balai_nadi_regression.tscn' -and -not ($output -match 'BALAI NADI REGRESSION COMPLETE: failures=0')) {
        throw 'Balai Nadi regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/greenhouse_regression.tscn' -and -not ($output -match 'GREENHOUSE REGRESSION COMPLETE: failures=0')) {
        throw 'Greenhouse regression tidak menyelesaikan semua pemeriksaan'
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
        'scenes/world/interior/university.tscn',
        'scenes/world/balai_nadi/exterior.tscn',
        'scenes/world/balai_nadi/interior.tscn'
    )) {
        Invoke-GodotCheck $scene @($scene, '--quit-after', '60')
    }
    Invoke-GodotCheck 'Co-op 2/3/4 players' @('tests/coop_smoke.tscn')
    Invoke-GodotCheck 'Inventory and settings menu' @('tests/menu_regression.tscn')
    Invoke-GodotCheck 'Crafting recipes and transactions' @('tests/crafting_regression.tscn')
    Invoke-GodotCheck 'Farm structures and storage' @('tests/structure_regression.tscn')
    Invoke-GodotCheck 'Gameplay regression' @('tests/gameplay_regression.tscn')
    Invoke-GodotCheck 'Tool tiers, capacity, area and upgrades' @('tests/tool_progression_regression.tscn')
    Invoke-GodotCheck 'Crop growth regression' @('tests/crop_regression.tscn')
    Invoke-GodotCheck 'Character animations' @('tests/character_animation_regression.tscn')
    Invoke-GodotCheck 'Balai Nadi contributions (expected save I/O error)' @('tests/balai_nadi_regression.tscn') $true
    Invoke-GodotCheck 'Greenhouse community restoration and farming' @('tests/greenhouse_regression.tscn')
    Invoke-GodotCheck 'Save regression (expected I/O errors)' @('tests/save_regression.tscn') $true
    Write-Host 'MVP verification passed.'
} finally {
    $env:APPDATA = $previousAppData
    $env:NUSA_SAVE_AUDIT = $previousAudit
    Write-Host "Data uji terisolasi disimpan di: $auditPath"
}
