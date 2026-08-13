# M7: Resource bundling script
# Copies required binaries from source project InterKnot_Auth-1.68 to assets/bin/
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/copy_bins.ps1
#
# Prerequisites:
#   1. Source project InterKnot_Auth-1.68 exists in the parent directory
#   2. Java JRE installed (or source project already contains jre/)

param(
    [string]$SourceProject = "..\InterKnot_Auth-1.68",
    [string]$TargetDir = "assets\bin"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TargetPath = Join-Path $ProjectRoot $TargetDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  InterKnot_Auth Flutter - Resource Bundling" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ensure target directory exists
if (-not (Test-Path $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Write-Host "[OK] Created target dir: $TargetPath" -ForegroundColor Green
}

$sourceFull = Join-Path $ProjectRoot $SourceProject
if (-not (Test-Path $sourceFull)) {
    Write-Host "[WARN] Source project not found: $sourceFull" -ForegroundColor Yellow
    Write-Host "       Place InterKnot_Auth-1.68 in the correct location, or copy resources manually." -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Source: $sourceFull" -ForegroundColor Gray
Write-Host "[INFO] Target: $TargetPath" -ForegroundColor Gray
Write-Host ""

# === 1. Copy login.jar ===
$loginJar = Join-Path $sourceFull "login.jar"
if (Test-Path $loginJar) {
    Copy-Item -Path $loginJar -Destination $TargetPath -Force
    Write-Host "[OK] Copied login.jar" -ForegroundColor Green
} else {
    Write-Host "[WARN] login.jar not found, skipped" -ForegroundColor Yellow
}

# === 2. Copy JRE directory ===
$jreDir = Join-Path $sourceFull "jre"
if (Test-Path $jreDir) {
    $jreTarget = Join-Path $TargetPath "jre"
    if (Test-Path $jreTarget) {
        Remove-Item -Recurse -Force $jreTarget
    }
    Copy-Item -Recurse -Path $jreDir -Destination $jreTarget -Force
    Write-Host "[OK] Copied jre/ directory" -ForegroundColor Green
} else {
    Write-Host "[WARN] jre/ directory not found, skipped (jar login requires JRE)" -ForegroundColor Yellow
}

# === 3. Copy EasyTier files ===
$easytierDir = Join-Path $sourceFull "easytier"
if (Test-Path $easytierDir) {
    $etTarget = Join-Path $TargetPath "easytier"
    if (Test-Path $etTarget) {
        Remove-Item -Recurse -Force $etTarget
    }
    Copy-Item -Recurse -Path $easytierDir -Destination $etTarget -Force
    Write-Host "[OK] Copied easytier/ directory" -ForegroundColor Green
} else {
    Write-Host "[WARN] easytier/ directory not found, skipped" -ForegroundColor Yellow
}

# === 4. Copy ddddocr OCR model ===
$ocrModel = Join-Path $sourceFull "ddddocr\common_old.onnx"
if (Test-Path $ocrModel) {
    $ocrTarget = Join-Path $TargetPath "ocr"
    if (-not (Test-Path $ocrTarget)) {
        New-Item -ItemType Directory -Path $ocrTarget -Force | Out-Null
    }
    Copy-Item -Path $ocrModel -Destination $ocrTarget -Force
    Write-Host "[OK] Copied ddddocr/common_old.onnx" -ForegroundColor Green
} else {
    Write-Host "[WARN] common_old.onnx not found, skipped" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resource bundling complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step:" -ForegroundColor White
Write-Host "  flutter build windows --release" -ForegroundColor Gray
