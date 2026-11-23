# Runs every check this project needs, in order, and stops at the first failure.
# Usage:  .\check.ps1
$ErrorActionPreference = 'Stop'

$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$app     = Join-Path $root 'CollabBoard\frontend\collabboard_app'
$backend = Join-Path $root 'CollabBoard\backend'

Write-Host '=== flutter analyze ===' -ForegroundColor Cyan
Push-Location $app
flutter analyze
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Host 'analyze failed' -ForegroundColor Red; exit 1 }

Write-Host '=== flutter test ===' -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Host 'tests failed' -ForegroundColor Red; exit 1 }
Pop-Location

Write-Host '=== backend syntax ===' -ForegroundColor Cyan
Push-Location $backend
Get-ChildItem src -Recurse -Filter *.js | ForEach-Object {
    node --check $_.FullName
    if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Host "syntax error in $($_.Name)" -ForegroundColor Red; exit 1 }
}
Pop-Location

Write-Host 'All checks passed.' -ForegroundColor Green
