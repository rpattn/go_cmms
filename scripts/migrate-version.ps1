# scripts/migrate-version.ps1
# Prints current migration version.
# Usage:  .\scripts\migrate-version.ps1

$ErrorActionPreference = "Stop"
if (-not $env:DATABASE_URL) {
  Write-Error "DATABASE_URL is not set. Run:  . ./scripts/env.ps1"
}

$path = Join-Path $PSScriptRoot "..\db\migrations"
migrate -path $path -database $env:DATABASE_URL version
