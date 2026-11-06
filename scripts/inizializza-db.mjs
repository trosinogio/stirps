// Prepara il database a ogni deploy, prima di `next build`. Al primo deploy carica tutto: schema, logica, seme pilota,
// etimologie e prime attestazioni di Wiktionary, glosse italiane del Wikizionario (dati/*.tsv.gz, già analizzati).
// Poi, a ogni deploy: applica gli aggiornamenti datati di db/aggiornamenti/ e, se il pacchetto dati è cambiato
// (la sua impronta non è quella registrata in meta), rifà l'import rispettando la redazione e toglie i residui.
// Senza stringa di connessione salta.
//
// Usa la stringa diretta (DATABASE_URL_UNPOOLED), come raccomandano le skill di Neon per migrazioni e caricamenti.
// Prova node-postgres; dove la porta 5432 è chiusa ripiega sul driver serverless di Neon via WebSocket (porta 443).
// I dati entrano a blocchi con unnest, che funziona con entrambi i driver.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import nextEnv from '@next/env';
import pg from 'pg';

nextEnv.loadEnvConfig(process.cwd());   // .env.local come per next build: stesse variabili in locale e su Vercel
const url = process.env.DATABASE_URL_UNPOOLED || process.env.POSTGRES_URL_NON_POOLING || process.env.DATABASE_URL;
if (!url) {
  console.log('[db] nessuna DATABASE_URL: salto l’inizializzazione');
  process.exit(0);
}

const SCHEMA = ['db/01_schema.sql', 'db/02_logica.sql', 'db/03_seed_pilota.sql', 'db/05_import_wiktionary.sql'];
const APPOGGIO = [
  ['stg_lingua', 'lingue'], ['stg_lessema', 'lessemi'], ['stg_ipotesi', 'ipotesi'],
  ['stg_relazione', 'relazioni'], ['stg_doppione', 'doppioni'], ['stg_radice', 'radici'],
  ['stg_attestazione', 'attestazioni'], ['stg_wikizionario', 'glosse_it'],
  ['stg_glossa_wikidata', 'glosse_wikidata'], ['stg_glossa_tradotta', 'glosse_tradotte'],
  ['stg_dizionario', 'dizionari'], ['stg_autore', 'autori'], ['stg_stima', 'stime'],
  ['stg_definizione', 'definizioni'], ['stg_pronuncia', 'pronunce'],
];
const BLOCCO = 5000;
// impronta del pacchetto dati: se cambia, al deploy si rifà l'import
const impronta = (() => {
  const h = createHash('sha256');
  for (const [, f] of APPOGGIO) if (existsSync(`dati/${f}.tsv.gz`)) h.update(f).update(readFileSync(`dati/${f}.tsv.gz`));
  // anche la logica dell'import: se cambia il modo di fondere i dati, al deploy si rifà l'import
  if (existsSync('db/05_import_wiktionary.sql')) h.update(readFileSync('db/05_import_wiktionary.sql'));
  return h.digest('hex').slice(0, 16);
})();
const t0 = Date.now();
const secondi = () => ((Date.now() - t0) / 1000).toFixed(1);

// tabelle di appoggio dal pacchetto dati, fusione nel dizionario, lemmi dei dizionari, glosse, viste; registra
// l'impronta. Tutto in una transazione: se qualcosa va storto il database resta com'era e il deploy si ferma.
// Dopo il commit le tabelle di appoggio si svuotano e il vacuum rende riusabile lo spazio delle righe sostituite
// (il piano gratuito di Neon ha 0,5 GB).
async function importa(client, pulisci) {
  await client.query('begin');
  try {
    await client.query(`truncate ${APPOGGIO.map(([t]) => t).join(', ')}`);
    for (const [tabella, file] of APPOGGIO) {
      const k = await carica(client, tabella, file);
      console.log(`[db]   ${tabella}: ${k} righe (${secondi()} s)`);
    }
    await client.query(`analyze ${APPOGGIO.map(([t]) => t).join(', ')}`);   // stime giuste per i piani della fusione
    const { rows: [r] } = await client.query('select importa_wiktionary() as r');
    console.log('[db] fusione:', JSON.stringify(r.r), `(${secondi()} s)`);
    if (pulisci) {
      const { rows: [p] } = await client.query('select pulisci_wiktionary() as p');
      console.log('[db] pulizia:', JSON.stringify(p.p), `(${secondi()} s)`);
    }
    const { rows: [d] } = await client.query('select importa_dizionari() as d');
    console.log('[db] dizionari:', JSON.stringify(d.d), `(${secondi()} s)`);
    const { rows: [stm] } = await client.query('select importa_stime() as s');
    console.log('[db] stime:', JSON.stringify(stm.s), `(${secondi()} s)`);
    const { rows: [g] } = await client.query('select importa_glosse_wikizionario() as g');
    console.log('[db] glosse italiane:', JSON.stringify(g.g), `(${secondi()} s)`);
    const { rows: [ga] } = await client.query('select importa_glosse_aggiuntive() as g');
    console.log('[db] glosse aggiuntive:', JSON.stringify(ga.g), `(${secondi()} s)`);
    const { rows: [df] } = await client.query('select importa_definizioni() as d');
    console.log('[db] definizioni:', JSON.stringify(df.d), `(${secondi()} s)`);
    const { rows: [pr] } = await client.query('select importa_pronunce() as p');
    console.log('[db] pronunce:', JSON.stringify(pr.p), `(${secondi()} s)`);
    await client.query('refresh materialized view mv_allotropi');
    console.log(`[db] mv_allotropi (${secondi()} s)`);
    await client.query('refresh materialized view mv_famiglia');
    console.log(`[db] mv_famiglia (${secondi()} s)`);
    const { rows: [st] } = await client.query(`select to_regclass('public.mv_storie') is not null as c`);
    if (st.c) await client.query('refresh materialized view mv_storie');    // le storie seguono famiglie e allotropi
    console.log(`[db] mv_storie (${secondi()} s)`);
    await client.query(`insert into meta (chiave, valore) values ('versione_dati', $1)
                        on conflict (chiave) do update set valore = excluded.valore, aggiornato_il = now()`, [impronta]);
    await client.query('commit');
    console.log(`[db] commit (${secondi()} s)`);
  } catch (e) {
    await client.query('rollback').catch(() => {});
    throw e;
  }
  await client.query(`truncate ${APPOGGIO.map(([t]) => t).join(', ')}`);
  await client.query('vacuum (analyze)');
  const { rows: [dim] } = await client.query('select pg_size_pretty(pg_database_size(current_database())) as d');
  console.log(`[db] spazio occupato: ${dim.d} (vacuum fatto, ${secondi()} s)`);
}

async function connetti() {
  const c = new pg.Client({ connectionString: url, connectionTimeoutMillis: 8000 });
  try {
    await c.connect();
    console.log('[db] connesso con node-postgres');
    return c;
  } catch (e) {
    await c.end().catch(() => {});
    if (!/neon\./.test(url)) throw e;
    // porta 5432 chiusa (sandbox, alcune reti aziendali): lo stesso protocollo via WebSocket
    const { Client } = await import('@neondatabase/serverless');
    const w = new Client({ connectionString: url });
    await w.connect();
    console.log(`[db] porta 5432 non raggiungibile (${e.code ?? e.message}): connesso via WebSocket`);
    return w;
  }
}

// Testo COPY: \N è null, \\ è una barra; i nostri file non contengono altri escape
const campo = (x) => (x === '\\N' ? null : x.replace(/\\\\/g, '\\'));

async function carica(client, tabella, file) {
  // i dizionari possono mancare in un pacchetto vecchio: la tabella resta vuota e importa_dizionari() non fa nulla
  if (['dizionari', 'autori', 'stime', 'definizioni', 'pronunce'].includes(file) && !existsSync(`dati/${file}.tsv.gz`)) return 0;
  const { rows: colonne } = await client.query(
    `select attname as nome, format_type(atttypid, atttypmod) as tipo from pg_attribute
      where attrelid = $1::regclass and attnum > 0 and not attisdropped order by attnum`, [tabella]);
  const righe = gunzipSync(readFileSync(`dati/${file}.tsv.gz`)).toString('utf8').split('\n').filter(Boolean);
  const sql = `insert into ${tabella} select ${colonne.map((c, i) => `c${i}::${c.tipo}`).join(', ')}
                 from unnest(${colonne.map((_, i) => `$${i + 1}::text[]`).join(', ')}) as u(${colonne.map((_, i) => `c${i}`).join(', ')})`;
  for (let i = 0; i < righe.length; i += BLOCCO) {
    const array = colonne.map(() => []);
    for (const r of righe.slice(i, i + BLOCCO)) {
      const v = r.split('\t');
      colonne.forEach((_, j) => array[j].push(v[j] === undefined ? null : campo(v[j])));
    }
    await client.query(sql, array);
  }
  return righe.length;
}

const client = await connetti();
try {
  // due build in parallelo (anteprima e produzione) non devono caricare due volte
  await client.query('select pg_advisory_lock(73021)');
  const { rows: [s] } = await client.query(`select to_regclass('public.lessema') is not null as c`);
  if (!s.c) {
    for (const f of SCHEMA) {
      console.log(`[db] ${f}`);
      await client.query(readFileSync(f, 'utf8'));
    }
  }
  await client.query(`create table if not exists meta (chiave text primary key, valore text not null,
                                                        aggiornato_il timestamptz not null default now())`);
  const { rows: [n] } = await client.query('select count(*)::int as n from lessema');
  if (n.n > 1000) {
    console.log(`[db] già pronto: ${n.n} lessemi`);
  } else if (!existsSync('dati/lessemi.tsv.gz')) {
    console.log('[db] schema e seme caricati; nessun dato d’import in dati/');
  } else {
    console.log('[db] carico le etimologie di Wiktionary e le glosse del Wikizionario');
    await importa(client, false);
    const { rows: [m] } = await client.query('select count(*)::int as n from lessema');
    console.log(`[db] pronto: ${m.n} lessemi, ${secondi()} s`);
  }
  // frequenze d'uso (ordinano la ricerca e la coda di verifica): anche su un database già pronto, se mancano
  const { rows: [fq] } = await client.query(`select to_regclass('public.frequenza') is not null as c`);
  if (fq.c && existsSync('dati/frequenze_it.tsv.gz')) {
    const { rows: [nf] } = await client.query('select count(*)::int as n from frequenza');
    if (nf.n === 0) {
      const k = await carica(client, 'frequenza', 'frequenze_it');
      await client.query('analyze frequenza');
      console.log(`[db] frequenze: ${k} forme`);
    }
  }
  // aggiornamenti datati (db/aggiornamenti/): tutti ripetibili senza danni, si applicano a ogni avvio in ordine di data
  if (existsSync('db/aggiornamenti')) {
    const { readdirSync } = await import('node:fs');
    for (const f of readdirSync('db/aggiornamenti').filter((x) => x.endsWith('.sql')).sort()) {
      await client.query(readFileSync(`db/aggiornamenti/${f}`, 'utf8'));
      console.log(`[db] aggiornamento: ${f}`);
    }
  }
  // pacchetto dati nuovo su un database già pronto: nuovo import (la redazione resta com'è) e pulizia dei residui
  if (existsSync('dati/lessemi.tsv.gz')) {
    const { rows: [v] } = await client.query(`select valore from meta where chiave = 'versione_dati'`);
    if (v?.valore === impronta) {
      console.log(`[db] dati già alla versione ${impronta}`);
    } else {
      console.log(`[db] dati nuovi (${v?.valore ?? 'nessuna versione'} → ${impronta}): nuovo import`);
      await importa(client, true);
      console.log(`[db] nuovo import completato, ${secondi()} s`);
    }
  }
} finally {
  await client.query('select pg_advisory_unlock(73021)').catch(() => {});
  await client.end();
}
