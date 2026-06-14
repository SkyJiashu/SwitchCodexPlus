// Usage: node fix-ccswitch-providers.js [db-path]
// Injects sandbox_mode + approval_policy into all codex providers in CC Switch SQLite.
const path = require('path');
const os   = require('os');
const Database = require(path.join(__dirname, '..', 'node_modules', 'better-sqlite3'));

const dbPath = process.argv[2] || path.join(os.homedir(), '.cc-switch', 'cc-switch.db');
console.log('Opening:', dbPath);

const db = new Database(dbPath);
const rows = db.prepare("SELECT id, name, app_type, settings_config FROM providers WHERE app_type = 'codex'").all();
console.log('Found ' + rows.length + ' codex provider(s)\n');

let updated = 0;
for (const row of rows) {
    let sc;
    try { sc = JSON.parse(row.settings_config || '{}'); }
    catch (e) {
        console.log('  [SKIP]    ' + row.id + ' (' + row.name + ') - invalid JSON: ' + e.message);
        continue;
    }

    let cfg = sc.config || '';
    const hasSandbox  = /^\s*sandbox_mode\s*=/m.test(cfg);
    const hasApproval = /^\s*approval_policy\s*=/m.test(cfg);

    if (hasSandbox && hasApproval) {
        console.log('  [OK]      ' + row.id + ' (' + row.name + ') - already patched');
        continue;
    }

    // Insert before first [table] section, or at end if none
    const tableMatch = cfg.match(/^\[/m);
    const insertAt   = tableMatch ? cfg.indexOf(tableMatch[0]) : cfg.length;

    let inject = '';
    if (!hasSandbox)  inject += 'sandbox_mode = "danger-full-access"\n';
    if (!hasApproval) inject += 'approval_policy = "never"\n';

    sc.config = cfg.slice(0, insertAt) + inject + cfg.slice(insertAt);

    db.prepare("UPDATE providers SET settings_config = ? WHERE id = ? AND app_type = 'codex'")
      .run(JSON.stringify(sc), row.id);
    console.log('  [UPDATED] ' + row.id + ' (' + row.name + ')');
    updated++;
}

db.close();
console.log('\nDone. Updated ' + updated + ' provider(s).');
