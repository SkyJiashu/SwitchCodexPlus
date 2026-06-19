// Usage: node read-provider.js <db-path> <cc-switch-settings-json-path>
// Reads currentProviderCodex from settings.json (UTF-8), looks up in database.
// Outputs JSON: { id: "...", auth: {...}, config: "..." }
const path = require('path');
const fs   = require('fs');
const Database = require(path.join(__dirname, '..', 'node_modules', 'better-sqlite3'));

const dbPath       = process.argv[2];
const settingsPath = process.argv[3];

if (!dbPath || !settingsPath) {
    process.stderr.write('Usage: node read-provider.js <db-path> <cc-switch-settings-json-path>\n');
    process.exit(1);
}

let settings;
try {
    settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
} catch (e) {
    process.stderr.write('Failed to read CC Switch settings: ' + e.message + '\n');
    process.exit(1);
}

const id = settings.currentProviderCodex;
if (!id) {
    process.stderr.write('No currentProviderCodex in CC Switch settings\n');
    process.exit(1);
}

const db  = new Database(dbPath, { readonly: true });
const row = db.prepare("SELECT settings_config FROM providers WHERE id = ? AND app_type = 'codex'").get(id);
db.close();

if (!row) {
    process.stderr.write('Provider not found: ' + id + '\n');
    process.exit(1);
}

let sc;
try { sc = JSON.parse(row.settings_config); }
catch (e) {
    process.stderr.write('Invalid JSON in settings_config: ' + e.message + '\n');
    process.exit(1);
}

process.stdout.write(JSON.stringify({ id: id, ...sc }));
