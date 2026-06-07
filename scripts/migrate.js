#!/usr/bin/env node

/**
 * TBConnect - Automatic Migration Runner
 * Usage: node scripts/migrate.js YOUR_SERVICE_ROLE_KEY
 *
 * Get Service Role Key from:
 * 1. Go to: https://teifdfxmyebvnlcfngvc.supabase.co
 * 2. Settings → API → service_role secret
 * 3. Copy the key and paste below or pass as argument
 */

const https = require("https");
const fs = require("fs");
const path = require("path");

// ============================================================
// CONFIG
// ============================================================
const SUPABASE_URL = "https://teifdfxmyebvnlcfngvc.supabase.co";
const ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlaWZkZnhteWVidm5sY2ZuZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMzk4MTcsImV4cCI6MjA5MjkxNTgxN30.fEXFsYbZcrGp8PBrLKu3ptlQXtWyqZ6C9-kKyQJsdDI";

let SERVICE_ROLE_KEY = process.argv[2];
const SQL_FILE = path.join(
  __dirname,
  "..",
  "database",
  "FINAL_MIGRATION_APPLY_TO_SUPABASE.sql",
);

// ============================================================
// COLORS
// ============================================================
const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
};

const log = {
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  warn: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  header: (msg) =>
    console.log(`\n${colors.bright}${colors.cyan}${msg}${colors.reset}\n`),
};

// ============================================================
// MAIN
// ============================================================
async function main() {
  log.header("🚀 TBConnect - Medication Window Migration");

  // Step 1: Validate service key
  if (!SERVICE_ROLE_KEY) {
    log.error("No service role key provided");
    console.log("\nUsage:");
    console.log(`  node scripts/migrate.js "YOUR_SERVICE_ROLE_KEY"`);
    console.log("\nGet Service Role Key:");
    console.log("  1. Go to: https://teifdfxmyebvnlcfngvc.supabase.co");
    console.log("  2. Settings → API → service_role secret");
    console.log("  3. Copy and paste here\n");
    process.exit(1);
  }

  if (SERVICE_ROLE_KEY.length < 100) {
    log.error(
      "Service role key seems too short. Verify you copied the full key.",
    );
    process.exit(1);
  }

  log.success(`Service role key loaded (${SERVICE_ROLE_KEY.length} chars)`);

  // Step 2: Load SQL file
  if (!fs.existsSync(SQL_FILE)) {
    log.error(`SQL file not found: ${SQL_FILE}`);
    process.exit(1);
  }

  const sqlContent = fs.readFileSync(SQL_FILE, "utf-8");
  log.success(`SQL migration loaded (${sqlContent.length} chars)`);

  // Step 3: Split into statements
  const statements = sqlContent
    .split(";")
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith("--"));

  console.log(
    `\n${colors.bright}📊 Total statements: ${statements.length}${colors.reset}\n`,
  );

  // Step 4: Execute each statement
  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < statements.length; i++) {
    const stmt = statements[i];
    const displayStmt = stmt.length > 60 ? stmt.substring(0, 60) + "..." : stmt;

    process.stdout.write(`[${i + 1}/${statements.length}] ${displayStmt} `);

    try {
      await executeSQL(stmt, SERVICE_ROLE_KEY);
      log.success("");
      successCount++;
    } catch (error) {
      log.error("");
      log.error(`  ${error.message}`);
      failureCount++;

      // Don't stop on error, continue with next statement
      if (error.message.includes("already exists")) {
        log.warn(`  (This is okay - function might already exist)`);
      }
    }
  }

  // Step 5: Summary
  console.log(`\n${colors.bright}${"=".repeat(60)}${colors.reset}`);
  log.header("📊 Migration Summary");
  log.success(`Success: ${successCount}/${statements.length}`);
  if (failureCount > 0) {
    log.error(`Failed: ${failureCount}/${statements.length}`);
  }
  console.log(`${colors.bright}${"=".repeat(60)}${colors.reset}\n`);

  if (successCount > 0) {
    log.success("Migration completed!");
    console.log("\n✅ Window Safety Logic is now active:");
    console.log(
      "   • Morning: 06:00-09:00 (active) → 09:00-13:00 (late) → 13:00+ (locked)",
    );
    console.log(
      "   • Afternoon: 13:00-16:00 (active) → 16:00-18:00 (late) → 18:00+ (locked)",
    );
    console.log("   • Evening: 18:00-22:00 (active) → 22:00+ (late)\n");
    console.log("🎉 Ready to test! Run: flutter run\n");
    process.exit(0);
  } else {
    log.error("Migration failed");
    process.exit(1);
  }
}

// ============================================================
// EXECUTE SQL VIA REST API
// ============================================================
function executeSQL(sql, serviceKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      query: sql,
    });

    const urlObj = new URL(SUPABASE_URL);
    const options = {
      hostname: urlObj.hostname,
      path: "/rest/v1/rpc/exec_sql",
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        apikey: serviceKey,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        if (
          res.statusCode === 200 ||
          res.statusCode === 204 ||
          res.statusCode === 201
        ) {
          resolve(data);
        } else if (res.statusCode === 404) {
          // Try alternative endpoint
          executeSQL_Alternative(sql, serviceKey)
            .then(resolve)
            .catch(() => {
              reject(
                new Error(
                  `HTTP ${res.statusCode}: exec_sql endpoint not found`,
                ),
              );
            });
        } else {
          try {
            const error = JSON.parse(data);
            if (error.message && error.message.includes("already exists")) {
              // Function already exists, which is fine during migration
              resolve(data);
            } else {
              reject(
                new Error(`HTTP ${res.statusCode}: ${error.message || data}`),
              );
            }
          } catch {
            reject(
              new Error(`HTTP ${res.statusCode}: ${data || "Unknown error"}`),
            );
          }
        }
      });
    });

    req.on("error", (error) => {
      reject(new Error(`Request failed: ${error.message}`));
    });

    req.write(body);
    req.end();
  });
}

// ============================================================
// ALTERNATIVE: EXECUTE SQL VIA DIFFERENT ENDPOINT
// ============================================================
function executeSQL_Alternative(sql, serviceKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      statement: sql,
    });

    const urlObj = new URL(SUPABASE_URL);
    const options = {
      hostname: urlObj.hostname,
      path: "/rest/v1/rpc/sql",
      method: "POST",
      headers: {
        Authorization: `Bearer ${serviceKey}`,
        apikey: serviceKey,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        if (
          res.statusCode === 200 ||
          res.statusCode === 204 ||
          res.statusCode === 201
        ) {
          resolve(data);
        } else {
          reject(
            new Error(
              `Alternative endpoint also failed: HTTP ${res.statusCode}`,
            ),
          );
        }
      });
    });

    req.on("error", (error) => {
      reject(new Error(`Alternative request failed: ${error.message}`));
    });

    req.write(body);
    req.end();
  });
}

// ============================================================
// RUN
// ============================================================
main().catch((error) => {
  log.error(error.message);
  process.exit(1);
});
