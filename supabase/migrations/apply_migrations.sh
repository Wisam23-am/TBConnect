#!/usr/bin/env bash
# Bash script to apply Supabase SQL migrations using psql
# Usage:
#   export SUPABASE_DB_URL="postgres://user:pass@host:port/dbname"
#   ./apply_migrations.sh

set -euo pipefail

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "Please set SUPABASE_DB_URL environment variable to your Postgres connection string." >&2
  exit 1
fi

BASE_DIR="$(dirname "$0")"
MIGRATIONS=(
  "002_add_late_reason.sql"
  "003_get_upcoming_visits.sql"
)

for m in "${MIGRATIONS[@]}"; do
  path="$BASE_DIR/$m"
  if [ ! -f "$path" ]; then
    echo "Migration file not found: $path" >&2
    exit 1
  fi
  echo "Applying $m..."
  psql "$SUPABASE_DB_URL" -f "$path"
done

echo "Migrations applied successfully."
