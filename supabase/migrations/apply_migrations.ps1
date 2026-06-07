# PowerShell script to apply Supabase SQL migrations using psql
# Usage:
#   $Env:SUPABASE_DB_URL = "postgres://user:pass@host:port/dbname"
#   ./apply_migrations.ps1
# Note: Supply a connection string with sufficient privileges (service_role or DB superuser).

if (-not $Env:SUPABASE_DB_URL) {
  Write-Error "Please set SUPABASE_DB_URL environment variable to your Postgres connection string."
  exit 1
}

$psql = "psql"
if (-not (Get-Command $psql -ErrorAction SilentlyContinue)) {
  Write-Error "psql not found in PATH. Install PostgreSQL client tools or use Supabase SQL editor instead."
  exit 1
}

$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$migrations = @(
  "002_add_late_reason.sql",
  "003_get_upcoming_visits.sql"
)

foreach ($m in $migrations) {
  $path = Join-Path $base $m
  if (-not (Test-Path $path)) {
    Write-Error "Migration file not found: $path"
    exit 1
  }

  Write-Host "Applying $m ..."
  & $psql $Env:SUPABASE_DB_URL -f $path
  if ($LASTEXITCODE -ne 0) {
    Write-Error "psql failed on $m"
    exit $LASTEXITCODE
  }
}

Write-Host "Migrations applied successfully."
