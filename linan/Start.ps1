param(
    [string]$PythonExecutable = "",
    [string]$HostAddress = "127.0.0.1",
    [ValidateRange(1024,65535)][int]$Port = 8765,
    [switch]$Background,
    [switch]$OpenBrowser
)
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
$url = "http://127.0.0.1:$Port"
function Test-Linan {
    try {
        $response = Invoke-RestMethod -Uri "$url/api/health" -TimeoutSec 2
        return ($response.status -eq 'ok' -and $response.app -eq 'linan-community-guard')
    } catch { return $false }
}
if (Test-Linan) {
    Write-Host "Linan is already running: $url" -ForegroundColor Green
    if ($OpenBrowser) { Start-Process $url }
    exit 0
}
if (-not $PythonExecutable) {
    $localPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
    $workspacePython = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\work\.venv\Scripts\python.exe"))
    if (Test-Path -LiteralPath $localPython) { $PythonExecutable = $localPython }
    elseif (Test-Path -LiteralPath $workspacePython) { $PythonExecutable = $workspacePython }
    else { $PythonExecutable = "python" }
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "frontend\dist\index.html"))) {
    throw "Frontend is missing. Run Setup.ps1 -RebuildFrontend first."
}
Write-Host "Linan: http://localhost:$Port  |  admin / Demo2026!" -ForegroundColor Green
if (-not $Background) {
    Write-Host "Press Ctrl+C to stop. Use -Background for persistent local operation."
    & $PythonExecutable -m uvicorn backend.main:app --host $HostAddress --port $Port
    exit $LASTEXITCODE
}
$runtime = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$stdout = Join-Path $runtime 'server.stdout.log'
$stderr = Join-Path $runtime 'server.stderr.log'
$pidFile = Join-Path $runtime 'server.json'
$pythonCommand = Get-Command $PythonExecutable -ErrorAction Stop
$serverProcess = Start-Process -FilePath $pythonCommand.Source -ArgumentList @('-m','uvicorn','backend.main:app','--host',$HostAddress,'--port',"$Port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$serverInfo = @{
    pid = $serverProcess.Id
    startedTicks = $serverProcess.StartTime.ToUniversalTime().Ticks.ToString()
    executable = $pythonCommand.Source
    url = $url
    project = $PSScriptRoot
}
$serverInfo | ConvertTo-Json | Set-Content -LiteralPath $pidFile -Encoding UTF8
$ready = $false
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    if (Test-Linan) { $ready = $true; break }
    $serverProcess.Refresh()
    if ($serverProcess.HasExited) { break }
    Start-Sleep -Milliseconds 500
}
if (-not $ready) {
    if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Tail 20 }
    throw "Linan did not become ready. Check runtime/server.stderr.log. If port $Port is occupied, select another -Port."
}
Write-Host "Linan is running in the background. Close this window safely. Stop it with Stop.ps1." -ForegroundColor Green
if ($OpenBrowser) { Start-Process $url }
exit 0
