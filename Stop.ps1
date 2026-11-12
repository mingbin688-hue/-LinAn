$ErrorActionPreference = 'Stop'
$pidFile = Join-Path $PSScriptRoot 'runtime\server.json'
if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Host 'No background Linan instance was recorded.'
    exit 0
}
$info = Get-Content -LiteralPath $pidFile -Raw | ConvertFrom-Json
$serverProcess = Get-Process -Id $info.pid -ErrorAction SilentlyContinue
if (-not $serverProcess) {
    Remove-Item -LiteralPath $pidFile -Force
    Write-Host 'Linan is already stopped.'
    exit 0
}
# StartTime is the identity check; Process.Path is unavailable for processes of
# other sessions/elevated owners, so only compare it when both sides expose it.
if ($serverProcess.StartTime.ToUniversalTime().Ticks.ToString() -ne "$($info.startedTicks)") {
    throw "Recorded process is gone and pid $($info.pid) belongs to another process. No process was stopped; delete runtime\server.json manually if the server is no longer running."
}
if ($info.executable -and $serverProcess.Path -and $serverProcess.Path -ne $info.executable) {
    throw 'Process identity changed. No process was stopped.'
}
Stop-Process -Id $serverProcess.Id
try { [void]$serverProcess.WaitForExit(10000) } catch {}
Remove-Item -LiteralPath $pidFile -Force
Write-Host 'Linan has stopped.' -ForegroundColor Green
