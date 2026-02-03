$ErrorActionPreference = "Stop"

# URLs to raw files on GitHub
$baseUrl = "https://raw.githubusercontent.com/TheLazyCat00/physik-ball/main"
$files = @("main.jl", "Project.toml", "Manifest.toml", "Physik_Kopfball.csv")

# Create a temporary directory
$tempDir = Join-Path $env:TEMP "physik-ball-run"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

Write-Host "Downloading files to $tempDir..." -ForegroundColor Cyan

foreach ($file in $files) {
    try {
        Invoke-WebRequest -Uri "$baseUrl/$file" -OutFile (Join-Path $tempDir $file)
    } catch {
        Write-Error "Failed to download $file. Please check your internet connection."
        exit 1
    }
}

# Check if Julia is installed
if (-not (Get-Command "julia" -ErrorAction SilentlyContinue)) {
    Write-Error "Julia is not installed. Please install Julia first: https://julialang.org/downloads/"
    exit 1
}

Write-Host "Setting up environment and running simulation..." -ForegroundColor Cyan
Write-Host "This might take a while on the first run..." -ForegroundColor Yellow

# Run Julia
Set-Location $tempDir
# Instantiate environment and run
julia --project=. -e 'import Pkg; Pkg.instantiate(); include("main.jl")' -- $args
