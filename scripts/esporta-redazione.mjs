// Copia del lavoro della redazione: tutto ciò che non viene da un import, e ciò che la redazione ha toccato.
// Una riga JSON per record, in ordine stabile, con gli indirizzi delle voci collegate: così la copia si legge,
// si confronta con Git e resta valida anche se il database viene ricaricato con identificativi diversi.
//   node scripts/esporta-redazione.mjs cartella
import { mkdirSync, writeFileSync } from 'node:fs';
import nextEnv from '@next/env';
import pg from 'pg';

nextEnv.loadEnvConfig(process.cwd());
const url = process.env.DATABASE_URL_UNPOOLED || process.env.DATABASE_URL;
const cartella = process.argv[2] || 'copia-redazione';
if (!url) { console.error('[copia] manca DATABASE_URL_UNPOOLED'); process.exit(1); }

const sl = (col) => `(select slug from lessema where id = ${col})`;
const TABELLE = {
  lessemi: `select to_jsonb(l) - 'lemma_norm' - 'translit_norm' as r from lessema l
             where l.provenienza <> 'wiktionary' or l.stato_editoriale <> 'importato' order by l.id`,
  ipotesi: `select to_jsonb(h) || jsonb_build_object('esito_slug', ${sl('h.esito_id')}) as r from ipotesi h
             where h.provenienza <> 'wiktionary' or h.stato_editoriale <> 'importato'
                or exists (select 1 from rimando m where m.ipotesi_id = h.id) order by h.id`,
  passaggi: `select to_jsonb(x) || jsonb_build_object('esito_slug', ${sl('x.esito_id')}, 'etimo_slug', ${sl('x.etimo_id')}) as r
               from relazione x join ipotesi h on h.id = x.ipotesi_id
              where x.provenienza <> 'wiktionary' or x.stato_editoriale <> 'importato'
                 or h.provenienza <> 'wiktionary' or h.stato_editoriale <> 'importato' order by x.id`,
  attestazioni: `select to_jsonb(a) || jsonb_build_object('lessema_slug', ${sl('a.lessema_id')}) as r from attestazione a
                  where a.provenienza <> 'wiktionary' or a.stato_editoriale <> 'importato' order by a.id`,
  glosse: `select to_jsonb(g) || jsonb_build_object('lessema_slug', ${sl('g.lessema_id')}) as r from glossa g
            where g.provenienza = 'redazione' or g.stato_editoriale <> 'importato' order by g.id`,
  fonti: `select to_jsonb(m) || jsonb_build_object('opera', o.sigla) as r from rimando m join opera o on o.id = m.opera_id order by m.id`,
  accezioni: `select to_jsonb(a) as r from accezione a order by a.id`,
  connessioni: `select to_jsonb(c) as r from connessione c order by c.id`,
  storico: `select to_jsonb(s) as r from storico s where coalesce(s.utente, '') <> '' order by s.id`,
};

let c = new pg.Client({ connectionString: url, connectionTimeoutMillis: 8000 });
try { await c.connect(); } catch {
  const { Client } = await import('@neondatabase/serverless');
  c = new Client({ connectionString: url }); await c.connect();
}
mkdirSync(cartella, { recursive: true });
const conti = {};
for (const [nome, sql] of Object.entries(TABELLE)) {
  const { rows } = await c.query(sql);
  writeFileSync(`${cartella}/${nome}.jsonl`, rows.map((x) => JSON.stringify(x.r)).join('\n') + (rows.length ? '\n' : ''));
  conti[nome] = rows.length;
}
const { rows: [v] } = await c.query(`select valore from meta where chiave = 'versione_dati'`).catch(() => ({ rows: [{}] }));
writeFileSync(`${cartella}/sommario.json`, JSON.stringify({ versione_dati: v?.valore ?? null, record: conti }, null, 2) + '\n');
await c.end();
console.log('[copia]', JSON.stringify(conti));
