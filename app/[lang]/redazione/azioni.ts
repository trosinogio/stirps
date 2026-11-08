'use server';
// Azioni della redazione. Ognuna controlla sessione e ruolo, scrive in una transazione firmata (lo storico
// registra l'autore), aggiorna le pagine pubbliche e, se cambia l'ipotesi accolta, ricalcola famiglie e allotropi.
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { after } from 'next/server';
import { auth } from '@/lib/auth/server';
import { richiediRedattore } from '@/lib/auth/redattore';
import { query, transazione } from '@/lib/db';
import { isLang } from '@/lib/i18n';

export type StatoAccesso = { esito?: string; inviato?: string } | null;

const lingua = (fd: FormData) => { const l = String(fd.get('lang') ?? 'it'); return isLang(l) ? l : 'it'; };
const testo = (fd: FormData, k: string) => { const v = String(fd.get(k) ?? '').trim(); return v || null; };

// ---- accesso ----
export async function inviaCodice(_: StatoAccesso, fd: FormData): Promise<StatoAccesso> {
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  if (!email.includes('@')) return { esito: 'accesso-errato' };
  // la risposta è la stessa per account esistenti e no: non si rivela chi è redattore
  await auth.emailOtp.sendVerificationOtp({ email, type: 'sign-in' }).catch(() => null);
  return { inviato: email };
}

export async function entraConCodice(_: StatoAccesso, fd: FormData): Promise<StatoAccesso> {
  const lang = lingua(fd);
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const otp = String(fd.get('codice') ?? '').replace(/\s/g, '');
  const { error } = await auth.signIn.emailOtp({ email, otp });
  if (error) return { esito: 'codice-errato', inviato: email };
  redirect(`/${lang}/redazione`);
}

export async function entraConPassword(_: StatoAccesso, fd: FormData): Promise<StatoAccesso> {
  const lang = lingua(fd);
  const { error } = await auth.signIn.email({
    email: String(fd.get('email') ?? '').trim().toLowerCase(),
    password: String(fd.get('password') ?? ''),
  });
  if (error) return { esito: 'accesso-errato' };
  redirect(`/${lang}/redazione`);
}

export async function esci(fd: FormData) {
  await auth.signOut();
  redirect(`/${lingua(fd)}/redazione/accesso`);
}

// ---- modifiche ----
function chiudi(lang: string, slug: string, esito: string, ricalcola: boolean) {
  for (const l of ['it', 'en']) {
    revalidatePath(`/${l}/w/${slug}`);
    revalidatePath(`/${l}`);
  }
  if (ricalcola) {
    // dopo la risposta: l'ipotesi accolta cambia famiglie e allotropi
    after(async () => {
      await query('refresh materialized view concurrently mv_famiglia');
      await query('refresh materialized view concurrently mv_allotropi');
      await query('refresh materialized view concurrently mv_storie').catch(() => null);
    });
  }
  redirect(`/${lang}/redazione/w/${slug}?esito=${esito}`);
}

export async function salvaVoce(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const id = Number(fd.get('lessema'));
  const slug = String(fd.get('slug'));
  const stato = String(fd.get('stato_editoriale'));
  const glossa = testo(fd, 'glossa_it');
  let esito = 'salvato';
  try {
    await transazione(r.email, async (q) => {
      const [l] = await q<{ glossa_lingua: string | null }>(
        `update lessema set stato_editoriale = $3::stato_editoriale where id = $1 and slug = $2 returning glossa_lingua`, [id, slug, stato]);
      if (!l) throw new Error('voce non trovata');
      if (glossa && l.glossa_lingua === 'it') {
        await q(`update lessema set glossa = $2 where id = $1 and glossa is distinct from $2`, [id, glossa]);
      } else if (glossa) {
        // una glossa del Wikizionario rivista resta sua (provenienza immutabile), e diventa «rivista»
        await q(`insert into glossa (lessema_id, lingua, testo, provenienza, stato_editoriale) values ($1, 'it', $2, 'redazione', 'rivisto')
                 on conflict (lessema_id, lingua) where accezione_id is null
                 do update set testo = excluded.testo, stato_editoriale = 'rivisto'
                 where glossa.testo is distinct from excluded.testo or glossa.stato_editoriale = 'importato'`, [id, glossa]);   // confermare una glossa importata la rende rivista
      }
    });
  } catch { esito = 'errore'; }
  chiudi(lang, slug, esito, false);
}

export async function salvaIpotesi(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const id = Number(fd.get('ipotesi'));
  const slug = String(fd.get('slug'));
  const stato = String(fd.get('stato'));
  const confidenza = Number(fd.get('confidenza'));
  const nota = testo(fd, 'nota');
  let esito = 'salvato';
  let ricalcola = false;
  try {
    await transazione(r.email, async (q) => {
      const [h] = await q<{ esito_id: number; stato: string }>(
        `select h.esito_id, h.stato from ipotesi h join lessema l on l.id = h.esito_id where h.id = $1 and l.slug = $2`, [id, slug]);
      if (!h) throw new Error('ipotesi non trovata');
      ricalcola = (h.stato === 'accolta') !== (stato === 'accolta');
      if (stato === 'accolta' && h.stato !== 'accolta') {
        await q(`update ipotesi set stato = 'alternativa' where esito_id = $1 and stato = 'accolta'`, [h.esito_id]);
      }
      await q(`update ipotesi set stato = $2::stato_ipotesi, confidenza = $3, nota = $4,
                      nota_lingua = case when nota is distinct from $4 then null else nota_lingua end,
                      stato_editoriale = case when stato_editoriale = 'importato' then 'rivisto'::stato_editoriale else stato_editoriale end
                where id = $1`, [id, stato, confidenza, nota]);
    });
  } catch (e) { esito = esitoFonti(e) ?? 'errore'; ricalcola = false; }
  chiudi(lang, slug, esito, ricalcola);
}

export async function aggiungiFonte(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const ipotesi = Number(fd.get('ipotesi'));
  const slug = String(fd.get('slug'));
  let esito = 'fonte-aggiunta';
  try {
    await transazione(r.email, async (q) => {
      const ok = await q(`select 1 from ipotesi h join lessema l on l.id = h.esito_id where h.id = $1 and l.slug = $2`, [ipotesi, slug]);
      if (!ok.length) throw new Error('ipotesi non trovata');
      await q(`insert into rimando (opera_id, sv, locus, posizione, nota, ipotesi_id) values ($1, $2, $3, $4::posizione_fonte, $5, $6)`,
        [Number(fd.get('opera')), testo(fd, 'sv'), testo(fd, 'locus'), String(fd.get('posizione') ?? 'accoglie'), testo(fd, 'nota'), ipotesi]);
      await q(`update ipotesi set stato_editoriale = 'rivisto' where id = $1 and stato_editoriale = 'importato'`, [ipotesi]);
    });
  } catch { esito = 'errore'; }
  chiudi(lang, slug, esito, false);
}

export async function togliFonte(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  let esito = 'fonte-tolta';
  try {
    await transazione(r.email, (q) => q(
      `delete from rimando where id = $1
          and ipotesi_id in (select h.id from ipotesi h join lessema l on l.id = h.esito_id where l.slug = $2)`,
      [Number(fd.get('rimando')), slug]));
  } catch (e) { esito = esitoFonti(e) ?? 'errore'; }
  chiudi(lang, slug, esito, false);
}

export async function verificaIpotesi(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const id = Number(fd.get('ipotesi'));
  const slug = String(fd.get('slug'));
  let esito = 'verificata';
  try {
    await transazione(r.email, async (q) => {
      const [h] = await q<{ opere: number; certezza: number }>(
        `select opere_a_sostegno(h.id) as opere, h.confidenza as certezza
           from ipotesi h join lessema l on l.id = h.esito_id where h.id = $1 and l.slug = $2`, [id, slug]);
      if (!h) throw new Error('ipotesi non trovata');
      // le regole delle norme («Fonti e citazioni»), che il vincolo del database ricontrolla al commit:
      // un'opera della bibliografia che propone o accoglie l'ipotesi, due per la certezza 4
      if (h.opere === 0) { esito = 'servono-fonti'; return; }
      if (h.certezza === 4 && h.opere < 2) { esito = 'servono-due-fonti'; return; }
      await q(`update ipotesi set stato_editoriale = 'verificato' where id = $1`, [id]);
    });
  } catch (e) { esito = esitoFonti(e) ?? 'errore'; }
  chiudi(lang, slug, esito, false);
}

// il vincolo sulle fonti di un'ipotesi verificata (controlla_ipotesi_verificata) diventa un esito comprensibile:
// scatta anche alzando a 4 la certezza o togliendo l'ultima fonte che la sostiene
function esitoFonti(e: unknown): string | null {
  const msg = String((e as { message?: string })?.message ?? e);
  if (/certezza 4/.test(msg)) return 'servono-due-fonti';
  if (/deve citare almeno/.test(msg)) return 'servono-fonti';
  return null;
}

// ---- catene: ipotesi, passaggi, etimi ----
const intero = (fd: FormData, k: string) => { const v = String(fd.get(k) ?? '').trim(); return /^-?\d+$/.test(v) ? Number(v) : null; };

// l'errore del database diventa un esito comprensibile
function esitoDa(e: unknown): string {
  const err = e as { code?: string; message?: string };
  const msg = String(err?.message ?? e);
  const fonti = esitoFonti(e);
  if (fonti) return fonti;
  if (/cicl/i.test(msg)) return 'ciclo';
  if (msg === 'etimo-mancante') return 'etimo-mancante';
  if (err?.code === '23505') return 'gia-presente';
  if (err?.code === '23514' || err?.code === '22P02') return 'dati-non-validi';
  return 'errore';
}

type Q = <R>(sql: string, params?: unknown[]) => Promise<R[]>;

// l'etimo scelto tra le voci, oppure una voce nuova (lingua e lemma); se c'è già, si usa quella
async function etimoDa(q: Q, fd: FormData): Promise<number> {
  const slug = testo(fd, 'etimo');
  if (slug) {
    const [e] = await q<{ id: number }>(`select id from lessema where slug = $1`, [slug]);
    if (!e) throw new Error('etimo-mancante');
    return e.id;
  }
  const lingua = testo(fd, 'nuova_lingua');
  const lemma = testo(fd, 'nuovo_lemma')?.replace(/^\*+/, '').trim();
  if (!lingua || !lemma) throw new Error('etimo-mancante');
  const [c] = await q<{ id: number }>(`select id from lessema where lingua = $1 and lemma = $2 order by omografo limit 1`, [lingua, lemma]);
  if (c) return c.id;
  const glossa = testo(fd, 'nuova_glossa');
  const [n] = await q<{ id: number }>(
    `insert into lessema (lingua, lemma, ricostruito, glossa, glossa_lingua, provenienza, stato_editoriale)
     values ($1, $2, $3, $4, case when $4::text is null then null else 'it' end, 'redazione', 'bozza') returning id`,
    [lingua, lemma, fd.get('nuovo_ricostruito') === 'on', glossa]);
  return n.id;
}

export async function nuovaIpotesi(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  const stato = String(fd.get('stato') ?? 'alternativa');
  let esito = 'ipotesi-creata';
  try {
    await transazione(r.email, async (q) => {
      const [l] = await q<{ id: number }>(`select id from lessema where slug = $1`, [slug]);
      if (!l) throw new Error('voce non trovata');
      if (stato === 'accolta') await q(`update ipotesi set stato = 'alternativa' where esito_id = $1 and stato = 'accolta'`, [l.id]);
      await q(`insert into ipotesi (esito_id, etichetta, stato, confidenza, origine, nota, provenienza, stato_editoriale)
               values ($1, $2, $3::stato_ipotesi, $4, $5::origine_tipo, $6, 'redazione', 'bozza')`,
        [l.id, testo(fd, 'etichetta') ?? 'redazione', stato, intero(fd, 'confidenza') ?? 3, String(fd.get('origine') ?? 'etimo'), testo(fd, 'nota')]);
    });
  } catch (e) { esito = esitoDa(e) === 'gia-presente' ? 'etichetta-usata' : esitoDa(e); }
  chiudi(lang, slug, esito, esito === 'ipotesi-creata' && stato === 'accolta');
}

export async function aggiungiArco(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  const ipotesi = Number(fd.get('ipotesi'));
  let esito = 'arco-aggiunto';
  let ricalcola = false;
  try {
    await transazione(r.email, async (q) => {
      const [h] = await q<{ id: number; esito_id: number; stato: string }>(
        `select h.id, h.esito_id, h.stato from ipotesi h join lessema l on l.id = h.esito_id where h.id = $1 and l.slug = $2`, [ipotesi, slug]);
      if (!h) throw new Error('ipotesi non trovata');
      const etimo = await etimoDa(q, fd);
      const anno = intero(fd, 'anno_da');
      await q(`insert into relazione (ipotesi_id, esito_id, etimo_id, tipo, ordine, forma_citata, affisso, confidenza, anno_da, precisione,
                                      provenienza, stato_editoriale)
               values ($1, $2, $3, $4, (select coalesce(max(ordine), 0) + 1 from relazione where ipotesi_id = $1), $5, $6, $7, $8,
                       case when $8::int is null then null else $9::precisione_data end, 'redazione', 'bozza')`,
        [h.id, h.esito_id, etimo, String(fd.get('tipo')), testo(fd, 'forma'), testo(fd, 'affisso'), intero(fd, 'confidenza') ?? 3, anno,
         String(fd.get('precisione') ?? 'esatta')]);
      await q(`update ipotesi set stato_editoriale = 'rivisto' where id = $1 and stato_editoriale = 'importato'`, [h.id]);
      ricalcola = h.stato === 'accolta';
    });
  } catch (e) { esito = esitoDa(e); ricalcola = false; }
  chiudi(lang, slug, esito, ricalcola);
}

export async function modificaArco(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  let esito = 'salvato';
  let ricalcola = false;
  try {
    await transazione(r.email, async (q) => {
      const anno = intero(fd, 'anno_da');
      const [a] = await q<{ stato: string }>(
        `update relazione x set tipo = $3, forma_citata = $4, affisso = $5, confidenza = $6, anno_da = $7,
                precisione = case when $7::int is null then null else $8::precisione_data end,
                stato_editoriale = case when x.stato_editoriale = 'importato' then 'rivisto'::stato_editoriale else x.stato_editoriale end
           from ipotesi h
          where x.id = $1 and h.id = x.ipotesi_id and x.esito_id = (select id from lessema where slug = $2)
          returning h.stato`,
        [Number(fd.get('relazione')), slug, String(fd.get('tipo')), testo(fd, 'forma'), testo(fd, 'affisso'), intero(fd, 'confidenza') ?? 3,
         anno, String(fd.get('precisione') ?? 'esatta')]);
      if (!a) throw new Error('passaggio non trovato');
      ricalcola = a.stato === 'accolta';
    });
  } catch (e) { esito = esitoDa(e); ricalcola = false; }
  chiudi(lang, slug, esito, ricalcola);
}

export async function togliArco(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  let esito = 'arco-tolto';
  let ricalcola = false;
  try {
    await transazione(r.email, async (q) => {
      const [a] = await q<{ stato: string }>(
        `delete from relazione x using ipotesi h
          where x.id = $1 and h.id = x.ipotesi_id and x.esito_id = (select id from lessema where slug = $2)
          returning h.stato`, [Number(fd.get('relazione')), slug]);
      if (!a) throw new Error('passaggio non trovato');
      ricalcola = a.stato === 'accolta';
    });
  } catch (e) { esito = esitoDa(e); ricalcola = false; }
  chiudi(lang, slug, esito, ricalcola);
}

// ---- date: prime attestazioni, con la loro fonte ----
export async function aggiungiAttestazione(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  let esito = 'attestazione-aggiunta';
  try {
    await transazione(r.email, async (q) => {
      const anno = intero(fd, 'anno_da');
      const txt = testo(fd, 'testo');
      if (anno === null || !txt) throw Object.assign(new Error('dati'), { code: '23514' });
      const [a] = await q<{ id: number }>(
        `insert into attestazione (lessema_id, testo, tipo, anno_da, anno_a, precisione, rif, forma_attestata, citazione, nota,
                                   provenienza, stato_editoriale)
         values ((select id from lessema where slug = $1), $2, $3, $4, $5, $6::precisione_data, $7, $8, $9, $10, 'redazione', 'bozza')
         returning id`,
        [slug, txt, String(fd.get('tipo') ?? 'letteraria'), anno, intero(fd, 'anno_a'), String(fd.get('precisione') ?? 'esatta'),
         testo(fd, 'rif'), testo(fd, 'forma_attestata'), testo(fd, 'citazione'), testo(fd, 'nota')]);
      const opera = intero(fd, 'opera');
      if (opera) {
        await q(`insert into rimando (opera_id, sv, locus, posizione, attestazione_id) values ($1, $2, $3, 'attesta', $4)`,
          [opera, testo(fd, 'sv'), testo(fd, 'locus'), a.id]);
      }
    });
  } catch (e) { esito = esitoDa(e); }
  chiudi(lang, slug, esito, false);
}

export async function togliAttestazione(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const slug = String(fd.get('slug'));
  let esito = 'attestazione-tolta';
  try {
    await transazione(r.email, (q) => q(
      `delete from attestazione where id = $1 and lessema_id = (select id from lessema where slug = $2)`, [Number(fd.get('attestazione')), slug]));
  } catch (e) { esito = esitoDa(e); }
  chiudi(lang, slug, esito, false);
}

// l'area di significato di una radice: confermata o scelta dalla redazione (imposta_area_radice(), con lo storico)
export async function salvaArea(fd: FormData) {
  const lang = lingua(fd);
  const r = await richiediRedattore(lang);
  const id = Number(fd.get('lessema'));
  const slug = String(fd.get('slug'));
  const area = String(fd.get('area') ?? '');
  let esito = 'salvato';
  try {
    await transazione(r.email, async (q) => {
      const [l] = await q<{ id: number }>(`select id from lessema where id = $1 and slug = $2 and ricostruito`, [id, slug]);
      if (!l || !area) throw new Error('dati non validi');
      await q(`select imposta_area_radice($1, $2)`, [id, area]);
    });
    for (const l of ['it', 'en']) revalidatePath(`/${l}/radici`, 'layout');
  } catch { esito = 'errore'; }
  chiudi(lang, slug, esito, false);
}
