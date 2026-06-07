#!/bin/bash
# ============================================================
# TBConnect - Apply Migration via psql
# Usage: bash scripts/apply_migration.sh
# ============================================================

SUPABASE_URL="https://teifdfxmyebvnlcfngvc.supabase.co"
DB_HOST="db.teifdfxmyebvnlcfngvc.supabase.co"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres"
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-}" # Set via environment or prompt

SQL_FILE="database/FINAL_MIGRATION_APPLY_TO_SUPABASE.sql"

echo "🚀 TBConnect - Medication Window Migration"
echo "==========================================================="
echo "Database: $DB_HOST:$DB_PORT/$DB_NAME"
echo "SQL File: $SQL_FILE"
echo "==========================================================="
echo ""

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo "❌ SQL file not found: $SQL_FILE"
    exit 1
fi

# Check if password provided
if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Database password required!"
    echo ""
    echo "Set password via environment:"
    echo "  export SUPABASE_DB_PASSWORD='your_postgres_password'"
    echo "  bash scripts/apply_migration.sh"
    echo ""
    exit 1
fi

echo "📖 Loading SQL migration..."
echo ""

# Apply migration using psql
PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -p "$DB_PORT" \
    -f "$SQL_FILE" \
    --no-password

RESULT=$?

echo ""
echo "==========================================================="
if [ $RESULT -eq 0 ]; then
    echo "🎉 Migration berhasil! Window safety logic sudah aktif."
    echo ""
    echo "Window Configuration:"
    echo "   • Morning: 06:00-09:00 (active) → 09:00-13:00 (late) → 13:00+ (locked)"
    echo "   • Afternoon: 13:00-16:00 (active) → 16:00-18:00 (late) → 18:00+ (locked)"
    echo "   • Evening: 18:00-22:00 (active) → 22:00+ (late)"
    echo ""
    echo "Jalankan app: flutter run"
else
    echo "❌ Migration failed with exit code: $RESULT"
    echo ""
    echo "Troubleshooting:"
    echo "1. Verify database password is correct"
    echo "2. Check network connectivity to $DB_HOST"
    echo "3. Ensure postgres user has sufficient privileges"
fi
echo "==========================================================="
echo ""
