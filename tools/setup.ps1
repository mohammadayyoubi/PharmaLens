# PharmaLens first-time setup for a new computer.
#
# Easiest: double-click setup.bat in the project folder.
# Or in PowerShell:  powershell -ExecutionPolicy Bypass -File tools\setup.ps1
#
# It checks the tools, creates the two private files git does not upload
# (lib/private/*.dart, from the *.example.dart templates), asks for the API
# keys (Enter skips), turns on the git hook that blocks committing a key,
# and downloads the packages. It never overwrites a private file that exists.
#
#   -Quick       only create missing private files, no questions (VS Code
#                runs this before every launch, so F5 always compiles)
#   -GeminiKey   / -PlacesKey  give the keys without being asked
#   -SkipDoctor  skip "flutter doctor" (faster)

param(
    [switch]$Quick,
    [string]$GeminiKey = '',
    [string]$PlacesKey = '',
    [switch]$SkipDoctor
)

# Not 'Stop': Windows PowerShell 5.1 turns anything a program prints on
# stderr (Flutter prints harmless notices there) into a fatal error.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$expectedFlutter = '3.47.2'
$geminiFile = 'lib\private\api_keys.dart'
$placesFile = 'lib\private\google_maps_private_config.dart'

function Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Ok($text) { Write-Host "   OK   $text" -ForegroundColor Green }
function Warn($text) { Write-Host "   !!   $text" -ForegroundColor Yellow }
function Info($text) { Write-Host "        $text" }

# Writes UTF-8 without a BOM (Dart reads it as is).
function Write-Utf8($path, $text) {
    $full = Join-Path $root $path
    [System.IO.File]::WriteAllText($full, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-KeyText($key) {
    return ($key -match '^[A-Za-z0-9_\.\-]{20,}$')
}

# Creates lib/private/api_keys.dart from its template, with $key if given.
function New-GeminiFile($key) {
    $text = Get-Content (Join-Path $root 'lib\private\api_keys.example.dart') -Raw
    if ($key) {
        $text = $text.Replace("// 'YOUR_API_KEY_HERE',", "'$key',")
    }
    Write-Utf8 $geminiFile $text
}

# Creates lib/private/google_maps_private_config.dart, with $key if given.
function New-PlacesFile($key) {
    $text = Get-Content (Join-Path $root 'lib\private\google_maps_private_config.example.dart') -Raw
    if ($key) {
        $text = $text.Replace("= 'YOUR_PLACES_API_KEY';", "= '$key';")
    }
    Write-Utf8 $placesFile $text
}

function Test-DevMode {
    try {
        $value = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name AllowDevelopmentWithoutDevLicense -ErrorAction Stop).AllowDevelopmentWithoutDevLicense
        return ($value -eq 1)
    } catch {
        return $false
    }
}

# --- Quick mode (VS Code, before each launch) -------------------------------
if ($Quick) {
    if (-not (Test-Path $geminiFile)) { New-GeminiFile ''; Write-Host "Created $geminiFile (no key yet: AI features are off)." }
    if (-not (Test-Path $placesFile)) { New-PlacesFile ''; Write-Host "Created $placesFile (no key yet: nearby pharmacies are off)." }
    exit 0
}

Write-Host 'PharmaLens setup' -ForegroundColor Cyan
Write-Host "Project folder: $root"

# --- 1. Flutter -------------------------------------------------------------
Step '1/6  Flutter'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Warn 'Flutter is not installed, or not on PATH.'
    Info 'Install it from https://docs.flutter.dev/get-started/install/windows/mobile'
    Info "(version $expectedFlutter, stable channel), then run this setup again."
    exit 1
}
$machine = (cmd /c "flutter --version --machine 2>nul" | Out-String)
$version = ''
if ($machine -match '"frameworkVersion"\s*:\s*"([^"]+)"') { $version = $Matches[1] }
if ($version -eq $expectedFlutter) {
    Ok "Flutter $version"
} else {
    Warn "Flutter $version is installed; the project uses $expectedFlutter."
    Info 'It may still work. To match exactly, ask your partner, or see'
    Info 'https://docs.flutter.dev/release/archive (download that version).'
}

# --- 2. Android tools and Java ----------------------------------------------
Step '2/6  Android SDK and Java'
if ($SkipDoctor) {
    Info 'Skipped (-SkipDoctor).'
} else {
    Info 'Running flutter doctor (takes about 20 seconds)...'
    $doctor = (cmd /c "flutter doctor -v 2>&1" | Out-String)
    if ($doctor -match 'Java version[^\r\n]*?(\d+)\.\d+') {
        $javaMajor = [int]$Matches[1]
        if ($javaMajor -ge 25) {
            Warn "Flutter uses Java $javaMajor; this project's Gradle needs Java 17 to 24."
            Info 'Install JDK 17 (https://learn.microsoft.com/java/openjdk/download), then run:'
            Info '  flutter config --jdk-dir="C:\Program Files\Microsoft\jdk-17..."   (your JDK 17 folder)'
        } else {
            Ok "Java $javaMajor"
        }
    } else {
        Warn 'No Java found for Android builds. Installing Android Studio includes one.'
    }
    if ($doctor -match '\[(X|!)\] Android toolchain') {
        Warn 'The Android toolchain needs attention. Open Android Studio > SDK Manager,'
        Info 'install "Android SDK Platform 37" and "Android SDK Command-line Tools", then run:'
        Info '  flutter doctor --android-licenses     (answer y to each)'
    } elseif ($doctor -match '\[(v|\u221A)\] Android toolchain') {
        Ok 'Android toolchain'
    }
}

# --- 3. Windows Developer Mode ------------------------------------------------
Step '3/6  Windows Developer Mode'
# Flutter links plugin folders with symlinks; on Windows that needs
# Developer Mode, or "flutter pub get" and every run fail in a new clone.
$tries = 0
while (-not (Test-DevMode) -and $tries -lt 3) {
    $tries++
    Warn 'Developer Mode is off. Flutter needs it on Windows to build this project.'
    Info 'Opening Settings: switch "Developer Mode" ON and confirm with Yes.'
    Start-Process 'ms-settings:developers'
    Read-Host '   When it is on, come back here and press Enter'
}
if (Test-DevMode) { Ok 'Developer Mode is on.' } else { Warn 'Developer Mode is still off; the packages step will fail until it is on.' }

# --- 4. Private files and API keys ------------------------------------------
Step '4/6  API keys (lib/private, never uploaded to GitHub)'
Info 'Each key is optional: without it the app still runs, only that feature is off.'
Info 'Get keys at https://aistudio.google.com/apikey (Gemini) and'
Info 'https://console.cloud.google.com/google/maps-apis (Places API (New)).'

if (Test-Path $geminiFile) {
    Ok "$geminiFile already exists (kept as it is)."
} else {
    if (-not $GeminiKey) { $GeminiKey = (Read-Host '   Paste the Gemini API key (or press Enter to skip)').Trim() }
    if ($GeminiKey -and -not (Test-KeyText $GeminiKey)) { Warn 'That does not look like an API key; skipped.'; $GeminiKey = '' }
    New-GeminiFile $GeminiKey
    if ($GeminiKey) { Ok "Created $geminiFile with your key." } else { Ok "Created $geminiFile without a key (prescription reading and the assistant are off)." }
}

if (Test-Path $placesFile) {
    Ok "$placesFile already exists (kept as it is)."
} else {
    if (-not $PlacesKey) { $PlacesKey = (Read-Host '   Paste the Google Places API key (or press Enter to skip)').Trim() }
    if ($PlacesKey -and -not (Test-KeyText $PlacesKey)) { Warn 'That does not look like an API key; skipped.'; $PlacesKey = '' }
    New-PlacesFile $PlacesKey
    if ($PlacesKey) { Ok "Created $placesFile with your key." } else { Ok "Created $placesFile without a key (nearby pharmacies are off)." }
}
Info 'To add or change a key later, edit those two files (or run this setup again after deleting them).'

# --- 5. Git hook --------------------------------------------------------------
Step '5/6  Git safety hook'
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $root '.git'))) {
    git config core.hooksPath .githooks
    Ok 'Commits that contain an API key are now blocked.'
} else {
    Warn 'Not a git clone (or git is not installed); skipped.'
}

# --- 6. Packages --------------------------------------------------------------
Step '6/6  Packages'
cmd /c "flutter pub get"
if ($LASTEXITCODE -ne 0) { Warn 'flutter pub get failed. Check the messages above (internet connection, Developer Mode) and run setup again.'; exit 1 }
Ok 'Packages downloaded.'

Write-Host ''
Write-Host 'Setup finished.' -ForegroundColor Green
Write-Host '  Run the app:  open this folder in VS Code and press F5,'
Write-Host '                or type:  flutter run'
Write-Host '  Phone:        turn on USB debugging and plug it in (flutter devices lists it).'
Write-Host '  Real speed:   use "flutter run --profile"; debug runs are much slower.'
