# ============================================================
# TBConnect - PowerShell Migration Script
# Run: .\scripts\run_migration.ps1
# ============================================================

param(
    [string]$ServiceKey = "",
    [string]$SqlFile = "database\FINAL_MIGRATION_APPLY_TO_SUPABASE.sql"
)

$SupabaseUrl = "https://teifdfxmyebvnlcfngvc.supabase.co"
$AnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlaWZkZnhteWVidm5sY2ZuZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzk4MTcsImV4cCI6MjA5MjkxNTgxN30.fEXFsYbZcrGp8PBrLKu3ptlQXtWyqZ6C9-kKyQJsdDI"

Write-Host ""
Write-Host "🚀 TBConnect - Medication Window Migration" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Supabase URL: $SupabaseUrl"
Write-Host "Config: $SqlFile"
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Check if SQL file exists
if (-not (Test-Path $SqlFile)) {
    Write-Host "❌ SQL file not found: $SqlFile" -ForegroundColor Red
    exit 1
}

# Read SQL file
$sqlContent = Get-Content $SqlFile -Raw
Write-Host "📖 Loaded SQL migration ($(($sqlContent | Measure-Object -Character).Characters) chars)" -ForegroundColor Yellow
Write-Host ""

# Check if service key provided
if ([string]::IsNullOrEmpty($ServiceKey)) {
    Write-Host "⚠️  SERVICE ROLE KEY REQUIRED FOR DDL OPERATIONS" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Provide service key as parameter:"
    Write-Host "  .\scripts\run_migration.ps1 -ServiceKey 'YOUR_SERVICE_ROLE_KEY'"
    Write-Host ""
    Write-Host "Option 2: Manual paste to SQL Editor:"
    Write-Host "  1. Open: https://teifdfxmyebvnlcfngvc.supabase.co"
    Write-Host "  2. Go to: SQL Editor → New Query"
    Write-Host "  3. Copy & paste from: $SqlFile"
    Write-Host "  4. Click RUN"
    Write-Host ""
    Write-Host "Option 3: Get Service Role Key:"
    Write-Host "  1. Open: https://teifdfxmyebvnlcfngvc.supabase.co"
    Write-Host "  2. Settings → API → Project API keys"
    Write-Host "  3. Copy 'service_role' (not anon key)"
    Write-Host ""
    exit 1
}

Write-Host "🔑 Service key provided ($(($ServiceKey | Measure-Object -Character).Characters) chars)" -ForegroundColor Green
Write-Host ""

# Split SQL into statements
$statements = $sqlContent -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
Write-Host "📊 Total SQL statements: $($statements.Count)" -ForegroundColor Yellow
Write-Host ""

# Execute migration
$successCount = 0
$failureCount = 0

for ($i = 0; $i -lt $statements.Count; $i++) {
    $statement = $statements[$i]
    $displayStmt = if ($statement.Length -gt 50) { $statement.Substring(0, 50) + "..." } else { $statement }
    
    Write-Host "[$($i+1)/$($statements.Count)] Executing: $displayStmt" -NoNewline
    
    try {
        # Create REST request body
        $body = @{
            query = $statement
        } | ConvertTo-Json

        # Execute via Supabase REST API with service role
        $response = Invoke-WebRequest `
            -Uri "$SupabaseUrl/rest/v1/rpc/exec_sql" `
            -Method Post `
            -Headers @{
                "Authorization" = "Bearer $ServiceKey"
                "apikey" = $ServiceKey
                "Content-Type" = "application/json"
            } `
            -Body $body `
            -ErrorAction Stop

        Write-Host " ✅" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Try alternative: direct query via psql or REST endpoint
        if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
            Write-Host "  ⚠️  RPC endpoint not found. Trying direct SQL..." -ForegroundColor Yellow
            try {
                # Try direct SQL execution (some Supabase setups support this)
                $response = Invoke-WebRequest `
                    -Uri "$SupabaseUrl/rest/v1/rpc/sql" `
                    -Method Post `
                    -Headers @{
                        "Authorization" = "Bearer $ServiceKey"
                        "apikey" = $ServiceKey
                        "Content-Type" = "application/json"
                    } `
                    -Body (@{ statement = $statement } | ConvertTo-Json) `
                    -ErrorAction Stop
                
                Write-Host "  ✅ (via alternative method)" -ForegroundColor Green
                $successCount++
            } catch {
                Write-Host "  Still failed: $($_.Exception.Message)" -ForegroundColor Red
                $failureCount++
            }
        } else {
            $failureCount++
        }
    }
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "📊 Migration Complete" -ForegroundColor Cyan
Write-Host "   ✅ Success: $successCount" -ForegroundColor Green
Write-Host "   ❌ Failed: $failureCount" -ForegroundColor Red
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

if ($failureCount -eq 0 -and $successCount -gt 0) {
    Write-Host "🎉 Migration berhasil! Window safety logic sudah aktif." -ForegroundColor Green
    Write-Host ""
    Write-Host "Window Configuration:" -ForegroundColor Cyan
    Write-Host "   • Morning: 06:00-09:00 (active) → 09:00-13:00 (late) → 13:00+ (locked)"
    Write-Host "   • Afternoon: 13:00-16:00 (active) → 16:00-18:00 (late) → 18:00+ (locked)"
    Write-Host "   • Evening: 18:00-22:00 (active) → 22:00+ (late)"
    Write-Host ""
    Write-Host "Jalankan app: flutter run" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Some operations failed. Check credentials and try manual SQL Editor." -ForegroundColor Yellow
}

Write-Host ""
