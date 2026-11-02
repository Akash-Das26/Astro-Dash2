# Runs the logic suite AND the UI audit, prints PASS/FAIL per check plus one
# summary line, and exits non-zero when either one fails or the audit reports
# any finding.
#
# Usage (PowerShell 5.1 or PowerShell 7):
#   powershell -ExecutionPolicy Bypass -File tests/run_all.ps1
#   powershell -ExecutionPolicy Bypass -File tests/run_all.ps1 -Godot "D:\Godot\godot_console.exe"

param(
    [string]$Godot = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
)

# Godot writes progress to stderr, so a native command must not be treated as a
# terminating error; the exit codes are checked explicitly below.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $Godot)) {
    $Godot = "godot"
    Write-Host "Godot not found at the default path; falling back to '$Godot' on PATH."
}

Write-Host "Running checks with: $Godot"
Write-Host "Project: $root"
Write-Host ""

# --- Logic suite -------------------------------------------------------------
$passed = 0
$failed = 0
$suiteLines = & $Godot --headless --path $root res://tests/run_tests.tscn 2>&1
$suiteExit = $LASTEXITCODE
if ($null -eq $suiteExit) {
    # The editor could not even be started, so there is no exit code to trust.
    $suiteExit = 1
}
foreach ($line in $suiteLines) {
    $text = [string]$line
    if ($text -match '^PASS (.+)$') {
        $passed++
    }
    elseif ($text -match '^FAIL (.+)$') {
        $failed++
        Write-Host ("FAIL " + $Matches[1]) -ForegroundColor Red
    }
    elseif ($text -match 'SUMMARY|FAILED:') {
        Write-Host $text
    }
}
Write-Host ("Logic suite: {0} passed, {1} failed (exit {2})" -f $passed, $failed, $suiteExit)
Write-Host ""

# --- UI alignment audit ------------------------------------------------------
$reported = -1
$seen = 0
$auditLines = & $Godot --headless --path $root res://tests/ui_audit.tscn 2>&1
$auditExit = $LASTEXITCODE
if ($null -eq $auditExit) {
    $auditExit = 1
}
foreach ($line in $auditLines) {
    $text = [string]$line
    if ($text -match 'FINDING (.+)$') {
        $seen++
        Write-Host ("FINDING " + $Matches[1]) -ForegroundColor Red
    }
    elseif ($text -match 'AUDIT DONE findings=(\d+)') {
        $reported = [int]$Matches[1]
    }
}
$findings = $reported
if ($findings -lt $seen) {
    # The run died before its closing line: trust the findings it printed.
    $findings = $seen
}
if ($findings -lt 0) {
    $findings = $seen
}
Write-Host ("UI audit: {0} findings (exit {1})" -f $findings, $auditExit)
Write-Host ""

# --- Verdict -----------------------------------------------------------------
if ($failed -gt 0 -or $suiteExit -ne 0 -or $findings -gt 0 -or $auditExit -ne 0) {
    Write-Host ("FAIL suite {0} passed / {1} failed (exit {2}); UI audit {3} findings (exit {4})" -f $passed, $failed, $suiteExit, $findings, $auditExit) -ForegroundColor Red
    exit 1
}
Write-Host ("SUMMARY suite {0} passed, 0 failed; UI audit 0 findings" -f $passed) -ForegroundColor Green
exit 0
