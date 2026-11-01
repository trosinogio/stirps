// Applica uno o più file SQL al database (in una transazione), per gli aggiornamenti dopo il primo caricamento.
// Uso: node scripts/applica-sql.mjs file.sql [altro.sql ...]
// Si connette come inizializza-db.mjs: node-postgres, oppure il driver di Neon via WebSocket se la porta 5432 è chiusa.
import { readFileSync } from 'node:fs';
import nextEnv from '@next/env';
import pg from 'pg';

nextEnv.loadEnvConfig(process.cwd());
const url = process.env.DATABASE_URL_UNPOOLED || process.env.POSTGRES_URL_NON_POOLING || process.env.DATABASE_URL;
const file = process.argv.slice(2);
if (!url) { console.error('[sql] manca DATABASE_URL'); process.exit(1); }
if (!file.length) { console.error('uso: node scripts/applica-sql.mjs file.sql [altro.sql ...]'); process.exit(1); }

async function connetti() {
  const c = new pg.Client({ connectionString: url, connectionTimeoutMillis: 8000 });
  try { await c.connect(); return c; } catch (e) {
    await c.end().catch(() => {});
    if (!/neon\./.test(url)) throw e;
    const { Client } = await import('@neondatabase/serverless');
    const w = new Client({ connectionString: url });
    await w.connect();
    return w;
  }
}

const client = await connetti();
try {
  await client.query('begin');
  for (const f of file) {
    await client.query(readFileSync(f, 'utf8'));
    console.log(`[sql] applicato ${f}`);
  }
  await client.query('commit');
} catch (e) {
  await client.query('rollback').catch(() => {});
  console.error(`[sql] annullato: ${e.message}`);
  process.exitCode = 1;
} finally {
  await client.end();
}
