$ErrorActionPreference = 'Stop'
$pidFile = Join-Path $PSScriptRoot 'runtime\server.json'
if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Host 'No background Linan instance was recorded.'
    exit 0
}
$info = Get-Content -LiteralPath $pidFile -Raw | ConvertFrom-Json
$serverProcess = Get-Process -Id $info.pid -ErrorAction SilentlyContinue
if (-not $serverProcess) {
    Write-Host 'Linan is already stopped.'
    exit 0
}
if ($serverProcess.StartTime.ToUniversalTime().Ticks.ToString() -ne $info.startedTicks -or $serverProcess.Path -ne $info.executable) {
    throw 'Process identity changed. No process was stopped.'
}
Stop-Process -Id $serverProcess.Id
Write-Host 'Linan has stopped.' -ForegroundColor Green
