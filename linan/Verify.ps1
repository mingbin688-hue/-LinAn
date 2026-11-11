param(
    [string]$PythonExecutable = '',
    [string]$FlutterExecutable = '',
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$InstallFrontendDependencies,
    [switch]$Package,
    [ValidateRange(30,3600)][int]$StepTimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($BackendOnly -and $FrontendOnly) { throw 'Choose only one of -BackendOnly and -FrontendOnly.' }
$runDirectory = Join-Path $PSScriptRoot ('runtime\verify\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$steps = [System.Collections.Generic.List[object]]::new()
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
    $fileName = $Executable
    $processArguments = $argumentLine
    if ($Executable -match '\.(bat|cmd)$') {
        # Start-Process and CreateProcess cannot launch batch files directly.
        $fileName = $env:ComSpec
        $processArguments = '/d /s /c ""' + $Executable + '" ' + $argumentLine + '"'
    }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $fileName
    $startInfo.Arguments = $processArguments
    $startInfo.WorkingDirectory = $Directory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit($StepTimeoutSeconds * 1000)
    if (-not $finished) {
        try { $process.Kill($true) } catch {}
        $process.WaitForExit()
    } else {
        # Ensure redirected streams are flushed after the process exits.
        $process.WaitForExit()
    }
    $standardOutput = $outputTask.GetAwaiter().GetResult()
    $standardError = $errorTask.GetAwaiter().GetResult()
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($stdout, $standardOutput, $utf8)
    [System.IO.File]::WriteAllText($stderr, $standardError, $utf8)
    $exitCode = if ($finished) { $process.ExitCode } else { -1 }
    $steps.Add([ordered]@{name=$Name;success=($exitCode -eq 0);exit_code=$exitCode;timed_out=(-not $finished);seconds=[Math]::Round(([DateTime]::UtcNow-$started).TotalSeconds,2);stdout=$stdout;stderr=$stderr})
    if ($standardOutput) { ($standardOutput -split "`r?`n" | Select-Object -Last 30) | Write-Host }
    if ($exitCode -ne 0) {
        if ($standardError) { ($standardError -split "`r?`n" | Select-Object -Last 30) | Write-Host }
        throw "$Name failed (exit $exitCode). See $runDirectory"
    }
}

function Resolve-Flutter {
    if ($FlutterExecutable) { return (Get-Command $FlutterExecutable -ErrorAction Stop).Source }
    $onPath = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -First 1
    $candidates = @($onPath.Source, 'E:\tools\flutter\bin\flutter.bat', (Join-Path $env:LOCALAPPDATA 'flutter\bin\flutter.bat'))
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    throw 'Flutter SDK not found. Run Setup.ps1 -RebuildFrontend with the SDK on PATH, or pass -FlutterExecutable.'
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
        $appDirectory = Join-Path $PSScriptRoot 'app'
        $flutter = Resolve-Flutter
        if ($InstallFrontendDependencies) {
            Invoke-VerificationStep 'flutter-pub' $flutter @('pub','get') $appDirectory
        }
        Invoke-VerificationStep 'flutter-analyze' $flutter @('analyze','--no-pub') $appDirectory
        Invoke-VerificationStep 'flutter-test' $flutter @('test','--no-pub') $appDirectory
        Invoke-VerificationStep 'flutter-build-web' $flutter @('build','web','--release','--no-pub') $appDirectory
    }
    if ($Package) { Invoke-VerificationStep 'package' $pythonPath @((Join-Path $PSScriptRoot 'scripts\package.py')) }
} catch {
    $failure = $_.Exception.Message
    Write-Host $failure -ForegroundColor Red
} finally {
    foreach ($name in $oldEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name,$oldEnvironment[$name],'Process') }
    $report = [ordered]@{success=($null -eq $failure);created_utc=[DateTime]::UtcNow.ToString('o');steps=@($steps.ToArray());error=$failure;output_directory=$runDirectory;model_verification='rules and mocked-provider tests only; no live supplier call'}
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runDirectory 'verification.json') -Encoding UTF8
    Write-Host "Verification report: $runDirectory\verification.json"
}
if ($failure) { exit 1 }
exit 0
