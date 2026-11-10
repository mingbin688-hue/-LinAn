param(
    [string]$PythonExecutable = '',
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$InstallFrontendDependencies,
    [switch]$Browser,
    [switch]$Package,
    [ValidateRange(30,3600)][int]$StepTimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($BackendOnly -and $FrontendOnly) { throw 'Choose only one of -BackendOnly and -FrontendOnly.' }
$runDirectory = Join-Path $PSScriptRoot ('runtime\verify\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$steps = [System.Collections.Generic.List[object]]::new()
$serverProcess = $null
$serverStartTicks = $null
$failure = $null
$oldEnvironment = @{}
foreach ($name in @('LINAN_DB','LINAN_URL','LINAN_OUTPUT_DIR','LINAN_LLM_ENABLED','LINAN_VERIFY_ISOLATED','PYTHONUTF8')) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Quote-NativeArgument([string]$Value) {
    # Standard Windows argv escaping, including trailing backslashes before a closing quote.
    return '"' + ([regex]::Replace(([regex]::Replace($Value, '(\\*)"', '$1$1\"')), '(\\+)$', '$1$1')) + '"'
}

function Invoke-VerificationStep([string]$Name, [string]$Executable, [string[]]$Arguments, [string]$Directory = $PSScriptRoot) {
    $stdout = Join-Path $runDirectory "$Name.stdout.log"
    $stderr = Join-Path $runDirectory "$Name.stderr.log"
    $started = [DateTime]::UtcNow
    Write-Host "Running $Name ..." -ForegroundColor Cyan
    $argumentLine = ($Arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' '
    $process = Start-Process -FilePath $Executable -ArgumentList $argumentLine -WorkingDirectory $Directory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $finished = $process.WaitForExit($StepTimeoutSeconds * 1000)
    if (-not $finished) {
        # This handle belongs to the process just started by this step.
        $process.Kill()
        $process.WaitForExit()
    }
    $exitCode = if ($finished) { $process.ExitCode } else { -1 }
    $steps.Add([ordered]@{name=$Name;success=($exitCode -eq 0);exit_code=$exitCode;timed_out=(-not $finished);seconds=[Math]::Round(([DateTime]::UtcNow-$started).TotalSeconds,2);stdout=$stdout;stderr=$stderr})
    if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Tail 30 | Write-Host }
    if ($exitCode -ne 0) {
        if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Tail 30 | Write-Host }
        throw "$Name failed (exit $exitCode). See $runDirectory"
    }
}

try {
    $env:PYTHONUTF8 = '1'
    $env:LINAN_LLM_ENABLED = '0'
    if (-not $PythonExecutable) {
        $candidates = @((Join-Path $PSScriptRoot '.venv\Scripts\python.exe'), [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\work\.venv\Scripts\python.exe')))
        $PythonExecutable = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $PythonExecutable) { $PythonExecutable = 'python' }
    }
    $pythonPath = (Get-Command $PythonExecutable -ErrorAction Stop).Source
    if (-not $FrontendOnly) {
        Invoke-VerificationStep 'backend' $pythonPath @('-m','pytest','tests','-q','-p','no:cacheprovider','--tb=short','-o','faulthandler_timeout=60','--basetemp',(Join-Path $runDirectory 'pytest'))
    }
    if (-not $BackendOnly) {
        $frontendDirectory = Join-Path $PSScriptRoot 'frontend'
        if ($InstallFrontendDependencies) {
            Push-Location -LiteralPath $frontendDirectory
            try {
                & pnpm install --frozen-lockfile
                if ($LASTEXITCODE -ne 0) { throw 'Locked frontend dependency installation failed.' }
            } finally { Pop-Location }
        }
        $nodePath = (Get-Command node -ErrorAction Stop).Source
        $typeChecker = Join-Path $frontendDirectory 'node_modules\vue-tsc\bin\vue-tsc.js'
        $vite = Join-Path $frontendDirectory 'node_modules\vite\bin\vite.js'
        if (-not (Test-Path -LiteralPath $typeChecker) -or -not (Test-Path -LiteralPath $vite)) {
            throw 'Frontend dependencies are missing. Run Verify.ps1 -InstallFrontendDependencies, or pnpm install --frozen-lockfile in frontend/.'
        }
        Invoke-VerificationStep 'typescript' $nodePath @($typeChecker,'--noEmit') $frontendDirectory
        Invoke-VerificationStep 'frontend-build' $nodePath @($vite,'build') $frontendDirectory
    }
    if ($Browser) {
        $nodePath = (Get-Command node -ErrorAction Stop).Source
        $env:LINAN_DB = Join-Path $runDirectory 'browser.sqlite3'
        $env:LINAN_OUTPUT_DIR = Join-Path $runDirectory 'browser'
        $env:LINAN_VERIFY_ISOLATED = '1'
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
        $env:LINAN_URL = "http://127.0.0.1:$port"
        $serverProcess = Start-Process -FilePath $pythonPath -ArgumentList @('-m','uvicorn','backend.main:app','--host','127.0.0.1','--port',"$port") -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runDirectory 'server.stdout.log') -RedirectStandardError (Join-Path $runDirectory 'server.stderr.log')
        $serverStartTicks = $serverProcess.StartTime.ToUniversalTime().Ticks
        $ready = $false
        for ($attempt=0; $attempt -lt 60; $attempt++) {
            $serverProcess.Refresh()
            if ($serverProcess.HasExited) { break }
            try {
                $health = Invoke-RestMethod -Uri "$env:LINAN_URL/api/health" -TimeoutSec 1
                if ($health.app -eq 'linan-community-guard') { $ready=$true; break }
            } catch {}
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) { throw "Isolated browser server did not start. See $runDirectory/server.stderr.log" }
        Invoke-VerificationStep 'browser' $nodePath @((Join-Path $PSScriptRoot 'tests\agents-browser.cjs'))
    }
    if ($Package) { Invoke-VerificationStep 'package' $pythonPath @((Join-Path $PSScriptRoot 'scripts\package.py')) }
} catch {
    $failure = $_.Exception.Message
    Write-Host $failure -ForegroundColor Red
} finally {
    if ($serverProcess) {
        $serverProcess.Refresh()
        if (-not $serverProcess.HasExited -and $serverProcess.StartTime.ToUniversalTime().Ticks -eq $serverStartTicks) { $serverProcess.Kill(); $serverProcess.WaitForExit() }
    }
    foreach ($name in $oldEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name,$oldEnvironment[$name],'Process') }
    $report = [ordered]@{success=($null -eq $failure);created_utc=[DateTime]::UtcNow.ToString('o');steps=@($steps.ToArray());error=$failure;output_directory=$runDirectory;model_verification='rules and mocked-provider tests only; no live supplier call'}
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDirectory 'verification.json') -Encoding UTF8
    Write-Host "Verification report: $runDirectory\verification.json"
}
if ($failure) { exit 1 }
exit 0
