This folder contains SQL migrations for the TBConnect Supabase project.

Files to apply (order matters):

- 002_add_late_reason.sql — add `late_reason` column and updated `log_medication_taken` RPC
- 003_get_upcoming_visits.sql — create `get_upcoming_visits` RPC

Apply locally using `psql` and a service-role connection string, or paste SQL into the Supabase SQL editor.

Examples:

PowerShell (Windows):

```powershell
$Env:SUPABASE_DB_URL = "postgres://<db_user>:<db_pass>@<db_host>:<port>/<db_name>"
cd supabase/migrations
./apply_migrations.ps1
```

Bash (macOS/Linux):

```bash
export SUPABASE_DB_URL="postgres://<db_user>:<db_pass>@<db_host>:<port>/<db_name>"
cd supabase/migrations
./apply_migrations.sh
```

If you don't have direct DB access, open each `.sql` file and execute its contents in the Supabase SQL editor (Project → SQL editor → New query). After running migrations, reload the app and retry the flows.
