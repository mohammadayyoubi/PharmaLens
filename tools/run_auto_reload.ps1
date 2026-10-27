# PharmaLens Auto-Reload Runner
# Automatically triggers Flutter Hot Reload ('r') whenever a .dart file is saved in lib/

Write-Host "Starting PharmaLens on Chrome with Auto-Reload on File Save..." -ForegroundColor Cyan

$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = "flutter"
$processInfo.Arguments = "run -d chrome --web-port=59115"
$processInfo.RedirectStandardInput = $true
$processInfo.RedirectStandardOutput = $false
$processInfo.UseShellExecute = $false

$process = [System.Diagnostics.Process]::Start($processInfo)

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = Join-Path $PSScriptRoot "..\lib"
$watcher.Filter = "*.dart"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

$lastReload = [DateTime]::MinValue

$action = {
    $now = [DateTime]::Now
    if (($now - $lastReload).TotalMilliseconds -gt 1500) {
        $lastReload = $now
        Write-Host "`n[Auto-Reload] Detected code change in lib/. Reloading..." -ForegroundColor Green
        try {
            $process.StandardInput.WriteLine("r")
        } catch {}
    }
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

try {
    $process.WaitForExit()
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
}
