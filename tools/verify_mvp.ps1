param(
    [string]$GodotPath = 'E:\Godot\Godot.exe',
    [int]$TimeoutSeconds = 120,
    [string[]]$Scenes = @(),
    [switch]$RecoveryEditor,
    [switch]$SkipEditor,
    [switch]$AllowCertificateStoreWarning
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot tidak ditemukan: $GodotPath" }
$auditPath = Join-Path ([System.IO.Path]::GetTempPath()) ('nusa-save-audit-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $auditPath | Out-Null
$previousAppData = $env:APPDATA
$previousAudit = $env:NUSA_SAVE_AUDIT
$script:verifiedScenes = [System.Collections.Generic.HashSet[string]]::new()

function Invoke-GodotCheck([string]$Label, [string[]]$Arguments, [bool]$ExpectedErrors = $false) {
    if ($Scenes.Count -gt 0 -and -not ($Arguments | Where-Object { $_ -in $Scenes })) { return }
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
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $timeoutLog = Join-Path $projectPath (Join-Path 'scratch' ('verify-timeout-' + ($Label -replace '[^A-Za-z0-9_-]', '_') + '.log'))
        try { $process.Kill($true) } catch { $process.Kill() }
        $process.WaitForExit()
        $partial = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [System.IO.File]::WriteAllText($timeoutLog, $partial)
        $process.Dispose()
        $partial -split "`r?`n" | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
        throw "$Label timeout setelah $TimeoutSeconds detik. Log: $timeoutLog"
    }
    $output = ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()) -split "`r?`n"
    $exitCode = $process.ExitCode
    $process.Dispose()
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) { throw "$Label gagal (exit $exitCode)" }
    foreach ($argument in $Arguments) {
        if ($argument -like 'tests/*.tscn') { [void]$script:verifiedScenes.Add($argument) }
    }
    if ($Arguments -contains 'tests/night_survival_regression.tscn' -and -not ($output -match 'NIGHT SURVIVAL REGRESSION COMPLETE: failures=0')) {
        throw 'Night survival regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/cooking_regression.tscn' -and -not ($output -match 'COOKING REGRESSION COMPLETE: failures=0')) {
        throw 'Cooking regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/early_progression_regression.tscn' -and -not ($output -match 'EARLY PROGRESSION COMPLETE: failures=0')) {
        throw 'Early progression regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/starter_routes_regression.tscn' -and -not ($output -match 'STARTER ROUTES COMPLETE: failures=0')) {
        throw 'Starter route regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/resource_spawner_regression.tscn' -and -not ($output -match 'RESOURCE SPAWNER COMPLETE: failures=0')) {
        throw 'Resource spawner regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/forest_ore_coop_regression.tscn' -and -not ($output -match 'FOREST ORE COOP COMPLETE: failures=0')) {
        throw 'Forest ore co-op regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($output -match 'SCRIPT ERROR:|FAIL:') {
        throw "$Label mengandung kegagalan script atau assertion"
    }
    # Keep the full log, but optionally tolerate only this known Windows environment error.
    $checkedOutput = $output
    if ($AllowCertificateStoreWarning) {
        $checkedOutput = $output | Where-Object { $_ -ne 'ERROR: Failed to read the root certificate store.' }
        if ($output -contains 'ERROR: Failed to read the root certificate store.') { Write-Warning 'Windows certificate store unavailable; explicitly tolerated for local gameplay tests.' }
    }
    if (-not $ExpectedErrors -and ($checkedOutput -match 'SCRIPT ERROR:|ERROR:')) {
        throw "$Label mengandung error Godot"
    }
    if ($Arguments -contains 'tests/daya_regression.tscn' -and -not ($output -match 'DAYA REGRESSION COMPLETE: failures=0')) {
        throw 'Biji Daya regression tidak menyelesaikan semua pemeriksaan'
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
    if ($Arguments -contains 'tests/farm_cleanup_regression.tscn' -and -not ($output -match 'FARM CLEANUP REGRESSION COMPLETE: failures=0')) {
        throw 'Farm cleanup regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/performance_ui_regression.tscn' -and -not ($output -match 'PERFORMANCE UI REGRESSION COMPLETE: failures=0')) {
        throw 'Performance UI regression tidak menyelesaikan semua pemeriksaan'
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
    if ($Arguments -contains 'tests/combat_regression.tscn' -and -not ($output -match 'COMBAT REGRESSION COMPLETE: failures=0')) {
        throw 'Combat regression tidak menyelesaikan semua pemeriksaan'
    }
    $completionMarkers = @{
        'tests/progression_balance_regression.tscn' = 'PROGRESSION BALANCE COMPLETE: failures=0'
        'tests/town_buildings_regression.tscn' = 'TOWN BUILDINGS COMPLETE: failures=0'
        'tests/role_exp_regression.tscn' = 'ROLE EXP REGRESSION COMPLETE: failures=0'
        'tests/npc_story_regression.tscn' = 'NPC STORY COMPLETE: failures=0'
        'tests/household_regression.tscn' = 'HOUSEHOLD COMPLETE: failures=0'
        'tests/role_coverage_regression.tscn' = 'ROLE COVERAGE COMPLETE: failures=0'
        'tests/house_regression.tscn' = 'HOUSE REGRESSION COMPLETE: failures=0'
        'tests/gathering_regression.tscn' = 'GATHERING REGRESSION COMPLETE: failures=0'
        'tests/fishing_season_regression.tscn' = 'FISHING SEASON COMPLETE: failures=0'
        'tests/portrait_expression_regression.tscn' = 'PORTRAIT REGRESSION COMPLETE'
        'tests/npc_social_regression.tscn' = 'NPC SOCIAL COMPLETE: failures=0'
    }
    foreach ($scene in $completionMarkers.Keys) {
        if ($Arguments -contains $scene -and -not ($output -match [regex]::Escape($completionMarkers[$scene]))) {
            throw "Tes $scene tidak menyelesaikan semua pemeriksaan"
        }
    }
    if ($Arguments -contains 'tests/structure_regression.tscn' -and -not ($output -match 'STRUCTURE REGRESSION COMPLETE: failures=0')) {
        throw 'Structure regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/furniture_regression.tscn' -and -not ($output -match 'FURNITURE REGRESSION COMPLETE: failures=0')) {
        throw 'Furniture regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/balai_nadi_regression.tscn' -and -not ($output -match 'BALAI NADI REGRESSION COMPLETE: failures=0')) {
        throw 'Balai Nadi regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/greenhouse_regression.tscn' -and -not ($output -match 'GREENHOUSE REGRESSION COMPLETE: failures=0')) {
        throw 'Greenhouse regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/npc_regression.tscn' -and -not ($output -match 'NPC REGRESSION COMPLETE: failures=0')) {
        throw 'NPC regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/ranch_regression.tscn' -and -not ($output -match 'RANCH REGRESSION COMPLETE: failures=0')) {
        throw 'Ranch regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/ranch_world_regression.tscn' -and -not ($output -match 'RANCH WORLD REGRESSION COMPLETE: failures=0')) {
        throw 'Ranch world regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/ranch_interior_regression.tscn' -and -not ($output -match 'RANCH INTERIOR REGRESSION COMPLETE: failures=0')) {
        throw 'Ranch interior regression tidak menyelesaikan semua pemeriksaan'
    }
    if ($Arguments -contains 'tests/production_audit.tscn' -and -not ($output -match 'PRODUCTION AUDIT COMPLETE: failures=0')) { throw 'Production audit tidak selesai' }
    if ($Arguments -contains 'tests/doors_livestock_shop_regression.tscn' -and -not ($output -match 'DOORS LIVESTOCK SHOP REGRESSION COMPLETE: failures=0')) { throw 'Doors/livestock shop regression tidak selesai' }
}

try {
    # SaveManager auto-loads on startup: isolate every run from real player saves.
    $env:APPDATA = $auditPath
    $env:NUSA_SAVE_AUDIT = '1'
    if ($SkipEditor) {
        Write-Host 'Editor/parser skipped explicitly; runtime checks only.'
    } elseif ($RecoveryEditor) {
        Invoke-GodotCheck 'Editor/parser (recovery mode, editor plugins disabled)' @('--editor', '--recovery-mode', '--quit')
    } else {
        Invoke-GodotCheck 'Editor/parser' @('--editor', '--quit')
    }
    Invoke-GodotCheck 'Main menu' @('--quit-after', '60')
    foreach ($scene in @(
        'scenes/world/farm.tscn',
        'scenes/world/Forest.tscn',
        'scenes/world/town.tscn',
        'scenes/world/interior/interior_house.tscn',
        'scenes/world/interior/school.tscn',
        'scenes/world/interior/university.tscn',
        'scenes/world/interior/barn_interior.tscn',
        'scenes/world/interior/coop_interior.tscn',
        'scenes/world/balai_nadi/exterior.tscn',
        'scenes/world/balai_nadi/interior.tscn'
    )) {
        Invoke-GodotCheck $scene @($scene, '--quit-after', '60')
    }
    Invoke-GodotCheck 'Night exploration, deadline and co-op recovery' @('tests/night_survival_regression.tscn')
    Invoke-GodotCheck 'Water stamina, overnight soil reset and resource tier gates' @('tests/farm_rules_regression.tscn')
    Invoke-GodotCheck 'Starter stock, renewable ore and Wood to Iron progression' @('tests/early_progression_regression.tscn')
    Invoke-GodotCheck 'Starter resource routes around locked mature obstacles' @('tests/starter_routes_regression.tscn')
    Invoke-GodotCheck 'Resource spawn clearance, restored overlap and tree depth' @('tests/resource_spawner_regression.tscn')
    Invoke-GodotCheck 'Shared Forest ore, owner stamina and reentry in co-op' @('tests/forest_ore_coop_regression.tscn')
    Invoke-GodotCheck 'Co-op 2/3/4 players' @('tests/coop_smoke.tscn')
    Invoke-GodotCheck 'Inventory and settings menu' @('tests/menu_regression.tscn')
    Invoke-GodotCheck 'Book paper bounds and pagination without scrolling' @('tests/inventory_book_layout_regression.tscn')
    Invoke-GodotCheck 'Gamepad inventory navigation and input bindings' @('tests/gamepad_input_regression.tscn')
    Invoke-GodotCheck 'Crafting recipes and transactions' @('tests/crafting_regression.tscn')
    Invoke-GodotCheck 'Combat HP, weapons, enemies and defeat' @('tests/combat_regression.tscn')
    Invoke-GodotCheck 'Dungeon shapes, editor zones and reachable routes' @('tests/dungeon_layout_regression.tscn')
    Invoke-GodotCheck 'Cave generation, mining and progression' @('tests/cave_regression.tscn')
    Invoke-GodotCheck 'Boss arena and combat' @('tests/boss_regression.tscn')
    Invoke-GodotCheck 'Cave exit interaction and confirmation' @('tests/cave_exit_input_regression.tscn')
    Invoke-GodotCheck 'Gold, Frost-Ember and Shadow cave tier content' @('tests/cave_tiers_regression.tscn')
    Invoke-GodotCheck 'Deep cave guardians and ranged enemies' @('tests/deep_cave_regression.tscn')
    Invoke-GodotCheck 'Chest proximity visuals for every tier' @('tests/chest_visual_regression.tscn')
    Invoke-GodotCheck 'Farm structures and storage' @('tests/structure_regression.tscn')
    Invoke-GodotCheck 'Furniture placement, rotation and seating' @('tests/furniture_regression.tscn')
    Invoke-GodotCheck 'Chicken coop, care, eggs and persistence' @('tests/chicken_regression.tscn')
    Invoke-GodotCheck 'Ranch care, production, grazing, upgrades and persistence' @('tests/ranch_regression.tscn')
    Invoke-GodotCheck 'Ranch walking animals, physical grazing and care UI' @('tests/ranch_world_regression.tscn')
    Invoke-GodotCheck 'Ranch interiors, solo transitions and building-specific co-op worlds' @('tests/ranch_interior_regression.tscn')
    Invoke-GodotCheck 'Processing durations, persistence and machine feedback' @('tests/production_audit.tscn')
    Invoke-GodotCheck 'Right-click doors and livestock shop purchases' @('tests/doors_livestock_shop_regression.tscn')
    Invoke-GodotCheck 'Automatic outdoor boundaries in solo and co-op' @('tests/outdoor_transition_regression.tscn')
    Invoke-GodotCheck 'Daily weather and outdoor rain watering' @('tests/weather_regression.tscn')
    Invoke-GodotCheck 'Artisan production, fruit trees, quality, keg, oil maker, smoker, lightning rod' @('tests/artisan_production_regression.tscn') $true
    Invoke-GodotCheck 'Television, weather forecast, living tips and cooking broadcast' @('tests/television_regression.tscn')
    Invoke-GodotCheck 'Forest river fishing, land and bridge boundaries' @('tests/forest_fishing_regression.tscn')
    Invoke-GodotCheck 'Instanced town buildings, interiors, doors and return spawns' @('tests/town_buildings_regression.tscn')
    Invoke-GodotCheck 'Deep Forest unlock, layout routes and resource persistence' @('tests/deep_forest_regression.tscn')
    Invoke-GodotCheck 'Free building placement and construction transactions' @('tests/placement_regression.tscn')
    Invoke-GodotCheck 'Carpenter solo and co-op map transitions' @('tests/carpenter_regression.tscn')
    Invoke-GodotCheck 'NPC interaction, dialogue bounds and controls' @('tests/npc_interaction_regression.tscn')
    Invoke-GodotCheck 'Asset-based service UI and purchase transactions' @('tests/service_ui_regression.tscn')
    Invoke-GodotCheck 'Tool pickup, single-item shipping and town Balai Nadi access' @('tests/request_feedback_regression.tscn')
    Invoke-GodotCheck 'Gameplay regression' @('tests/gameplay_regression.tscn')
    Invoke-GodotCheck 'Crop, livestock and tool upgrade economy balance' @('tests/economy_balance_regression.tscn')
    Invoke-GodotCheck 'Progression, cooking arbitrage, stamina and matched cave gear' @('tests/progression_balance_regression.tscn')
    Invoke-GodotCheck 'Cooking, recipe ownership, full-bag rollback and food effects' @('tests/cooking_regression.tscn')
    Invoke-GodotCheck 'One-time farm cleanup' @('tests/farm_cleanup_regression.tscn')
    Invoke-GodotCheck 'Deferred inventory and character cache' @('tests/performance_ui_regression.tscn')
    Invoke-GodotCheck 'Tool tiers, capacity, area and upgrades' @('tests/tool_progression_regression.tscn')
    Invoke-GodotCheck 'Focus pause, sleep alignment and water HUD' @('tests/feedback_focus_regression.tscn')
    Invoke-GodotCheck 'Crop growth regression' @('tests/crop_regression.tscn')
    Invoke-GodotCheck 'Character animations' @('tests/character_animation_regression.tscn')
    Invoke-GodotCheck 'Role EXP progression and persistence' @('tests/role_exp_regression.tscn')
    Invoke-GodotCheck 'Role branches and cooperative effects' @('tests/role_coverage_regression.tscn')
    Invoke-GodotCheck 'NPC story and romance' @('tests/npc_story_regression.tscn')
    Invoke-GodotCheck 'Household and social recipe mail' @('tests/household_regression.tscn')
    Invoke-GodotCheck 'Inventory skill tree page' @('tests/skill_tree_ui_regression.tscn')
    Invoke-GodotCheck 'Inventory NPC relationship page' @('tests/npc_relationship_ui_regression.tscn')
    Invoke-GodotCheck 'NPC schedules, waypoints, animations and dialogues' @('tests/npc_regression.tscn')
    Invoke-GodotCheck 'House upgrades, kitchen access and migration' @('tests/house_regression.tscn')
    Invoke-GodotCheck 'Bugs, bait, tappers and planted trees' @('tests/gathering_regression.tscn')
    Invoke-GodotCheck 'Seasonal fish and frozen water' @('tests/fishing_season_regression.tscn')
    Invoke-GodotCheck 'NPC portrait expressions' @('tests/portrait_expression_regression.tscn')
    Invoke-GodotCheck 'Per-player NPC friendship, gifting and persistence' @('tests/npc_social_regression.tscn')
    Invoke-GodotCheck 'Balai Nadi contributions (expected save I/O error)' @('tests/balai_nadi_regression.tscn') $true
    Invoke-GodotCheck 'Greenhouse community restoration and farming' @('tests/greenhouse_regression.tscn') $false
    Invoke-GodotCheck 'Balai wings, funds and greenhouse reward' @('tests/balai_wings_regression.tscn') $true
    Invoke-GodotCheck 'Biji Daya unique rewards, consumption and persistence' @('tests/daya_regression.tscn') $true
    Invoke-GodotCheck 'Save regression (expected I/O errors)' @('tests/save_regression.tscn') $true
    $missingScenes = @($Scenes | Where-Object { -not $script:verifiedScenes.Contains($_) })
    if ($missingScenes.Count -gt 0) { throw ('Selected scenes were not registered/executed: ' + ($missingScenes -join ', ')) }
    if ($Scenes.Count -gt 0) { Write-Host 'Selected MVP verification passed.' }
    elseif ($SkipEditor) { Write-Host 'MVP runtime verification passed (editor/parser skipped).' }
    elseif ($RecoveryEditor) { Write-Host 'MVP verification passed (editor recovery mode).' }
    else { Write-Host 'MVP verification passed.' }
} finally {
    $env:APPDATA = $previousAppData
    $env:NUSA_SAVE_AUDIT = $previousAudit
    Write-Host "Data uji terisolasi disimpan di: $auditPath"
}
