// Usage: node read-provider.js <db-path> <provider-id>
// Outputs JSON: { auth: {...}, config: "..." }
const path = require('path');
const Database = require(path.join(__dirname, '..', 'node_modules', 'better-sqlite3'));

const dbPath = process.argv[2];
const id     = process.argv[3];

if (!dbPath || !id) {
    process.stderr.write('Usage: node read-provider.js <db-path> <provider-id>\n');
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

process.stdout.write(JSON.stringify(sc));
