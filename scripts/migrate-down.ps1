# scripts/migrate-down.ps1
# Rolls back N migrations (default 1).
# Usage:  .\scripts\migrate-down.ps1 3

param([int]$Steps = 1)

$ErrorActionPreference = "Stop"
if (-not $env:DATABASE_URL) {
  Write-Error "DATABASE_URL is not set. Run:  . ./scripts/env.ps1"
}

$path = Join-Path $PSScriptRoot "..\db\migrations"
Write-Host "Rolling DOWN $Steps step(s) from $path"
migrate -path $path -database $env:DATABASE_URL down $Steps
