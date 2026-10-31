# Runs the headless test suite and prints PASS/FAIL per test plus a final count.
# Usage: pwsh -File tests/run_all.ps1 [-Godot <path to godot_console.exe>]

param(
    [string]$Godot = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $Godot)) {
    $Godot = "godot"
    Write-Host "Godot not found at the default path; falling back to '$Godot' on PATH."
}

Write-Host "Running tests with: $Godot"
Write-Host "Project: $root"

$lines = & $Godot --headless --path $root res://tests/run_tests.tscn 2>&1
$exit = $LASTEXITCODE

$passed = 0
$failed = 0
foreach ($line in $lines) {
    $text = [string]$line
    if ($text -match '^PASS (.+)$') {
        $passed++
        Write-Host ("PASS " + $Matches[1]) -ForegroundColor Green
    }
    elseif ($text -match '^FAIL (.+)$') {
        $failed++
        Write-Host ("FAIL " + $Matches[1]) -ForegroundColor Red
    }
    elseif ($text -match 'SUMMARY|FAILED:') {
        Write-Host $text
    }
}

Write-Host ""
Write-Host ("TOTAL: {0} passed, {1} failed" -f $passed, $failed)
if ($failed -gt 0 -or $exit -ne 0) {
    exit 1
}
exit 0
