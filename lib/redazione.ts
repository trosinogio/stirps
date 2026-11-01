// Interrogazioni della redazione: coda di verifica, contatori, storico, voce con ipotesi e rimandi
import { query } from './db';
import type { Lang } from './i18n';
import type { Nodo } from './tipi';

export interface VoceCoda { slug: string; lemma: string; rango: number; stato_editoriale: string; ipotesi_accolta: string | null; rimandi: number; glossa: string | null }
export interface Modifica { momento: string; utente: string; tabella: string; operazione: string; slug: string | null; lemma: string | null }
export interface VoceRedazione {
  id: number; slug: string; lemma: string; lingua: string; lingua_nome: string; pos: string | null; ricostruito: boolean;
  glossa: string | null; glossa_lingua: string | null; glossa_it: string | null; stato_editoriale: string; provenienza: string;
}
export interface Rimando { id: number; sigla: string; sv: string | null; locus: string | null; posizione: string; nota: string | null }
export interface IpotesiRedazione {
  id: number; etichetta: string; stato: string; confidenza: number; origine: string; nota: string | null; nota_lingua: string | null;
  provenienza: string; stato_editoriale: string;
  archi: { id: number; tipo: string; tipo_nome: string; etimo: Nodo; affisso: string | null; forma: string | null; confidenza: number;
           anno_da: number | null; anno_a: number | null; precisione: string | null }[];
  rimandi: Rimando[];
}

export async function codaVerifica(lang: Lang, limite = 60): Promise<VoceCoda[]> {
  return query<VoceCoda>(
    `select v.slug, v.lemma, v.rango, v.stato_editoriale, v.ipotesi_accolta, v.rimandi::int,
            coalesce((select g.testo from glossa g where g.lessema_id = v.id and g.lingua = $1 and g.accezione_id is null), l.glossa) as glossa
       from v_da_verificare v join lessema l on l.id = v.id
      order by v.rango, v.lemma limit $2`, [lang, limite]);
}

export async function contatori(): Promise<{ da_verificare: number; verificate: number; modifiche: number }> {
  const r = await query<{ da_verificare: number; verificate: number; modifiche: number }>(
    `select (select count(*)::int from v_da_verificare) as da_verificare,
            (select count(*)::int from ipotesi where stato_editoriale = 'verificato') as verificate,
            (select count(*)::int from storico where coalesce(utente, '') <> '' and momento > now() - interval '7 days') as modifiche`);
  return r[0];
}

// lo storico firmato: per ogni riga, la voce a cui si riferisce
export async function ultimeModifiche(limite = 15): Promise<Modifica[]> {
  return query<Modifica>(
    `select s.momento, s.utente, s.tabella, s.operazione, l.slug, l.lemma
       from storico s
       left join lateral (select coalesce(
              case s.tabella when 'lessema' then s.record_id end,
              (coalesce(s.dopo, s.prima)->>'lessema_id')::bigint,
              (coalesce(s.dopo, s.prima)->>'esito_id')::bigint,
              (select h.esito_id from ipotesi h where h.id = (coalesce(s.dopo, s.prima)->>'ipotesi_id')::bigint)) as lid) x on true
       left join lessema l on l.id = x.lid
      where coalesce(s.utente, '') <> ''
      order by s.id desc limit $1`, [limite]);
}

export async function voceRedazione(slug: string, lang: Lang): Promise<VoceRedazione | null> {
  const r = await query<VoceRedazione>(
    `select l.id, l.slug, l.lemma, l.lingua, coalesce(etichetta_in('lingua', l.lingua, $2), g.nome) as lingua_nome, l.pos, l.ricostruito,
            l.glossa, l.glossa_lingua,
            (select t.testo from glossa t where t.lessema_id = l.id and t.lingua = 'it' and t.accezione_id is null) as glossa_it,
            l.stato_editoriale, l.provenienza
       from lessema l join lingua g on g.codice = l.lingua where l.slug = $1`, [slug, lang]);
  return r[0] ?? null;
}

export async function ipotesiRedazione(lessemaId: number, lang: Lang): Promise<IpotesiRedazione[]> {
  return query<IpotesiRedazione>(
    `select h.id, h.etichetta, h.stato, h.confidenza, h.origine, h.nota, h.nota_lingua, h.provenienza, h.stato_editoriale,
            coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'tipo', r.tipo, 'confidenza', r.confidenza,
                        'anno_da', r.anno_da, 'anno_a', r.anno_a, 'precisione', r.precisione,
                        'tipo_nome', coalesce(etichetta_in('tipo_relazione', r.tipo, $2, 'breve'), r.tipo),
                        'etimo', nodo_json(r.etimo_id, $2, true),
                        'affisso', r.affisso, 'forma', r.forma_citata) order by r.ordine)
                        from relazione r where r.ipotesi_id = h.id), '[]'::jsonb) as archi,
            coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'sigla', o.sigla, 'sv', m.sv, 'locus', m.locus,
                        'posizione', m.posizione, 'nota', m.nota) order by m.id)
                        from rimando m join opera o on o.id = m.opera_id where m.ipotesi_id = h.id), '[]'::jsonb) as rimandi
       from ipotesi h where h.esito_id = $1
      order by (h.stato = 'accolta') desc, h.id`, [lessemaId, lang]);
}

export async function opereScelta(): Promise<{ id: number; sigla: string; titolo: string; ambito: string | null }[]> {
  return query(`select id, sigla, titolo, ambito from opera where modello_url is null or tipo <> 'in_rete' order by ambito nulls last, sigla`);
}

export interface AttestazioneRedazione {
  id: number; anno_da: number; anno_a: number | null; precisione: string; testo: string; rif: string | null; tipo: string;
  forma_attestata: string | null; citazione: string | null; nota: string | null; provenienza: string; stato_editoriale: string;
  rimandi: Rimando[];
}

export async function attestazioniRedazione(lessemaId: number): Promise<AttestazioneRedazione[]> {
  return query<AttestazioneRedazione>(
    `select a.id, a.anno_da, a.anno_a, a.precisione, a.testo, a.rif, a.tipo, a.forma_attestata, a.citazione, a.nota,
            a.provenienza, a.stato_editoriale,
            coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'sigla', o.sigla, 'sv', m.sv, 'locus', m.locus,
                        'posizione', m.posizione, 'nota', m.nota) order by m.id)
                        from rimando m join opera o on o.id = m.opera_id where m.attestazione_id = a.id), '[]'::jsonb) as rimandi
       from attestazione a where a.lessema_id = $1 order by a.anno_da, a.id`, [lessemaId]);
}

// i tipi di passaggio, raggruppati per categoria, con il nome nella lingua dell'interfaccia
export async function tipiRelazione(lang: Lang): Promise<{ codice: string; categoria: string; nome: string }[]> {
  return query(
    `select codice, categoria, coalesce(etichetta_in('tipo_relazione', codice, $1), etichetta) as nome
       from tipo_relazione
      order by case categoria when 'trasmissione' then 0 when 'formazione' then 1 when 'indeterminata' then 2 else 3 end, codice`, [lang]);
}

// le lingue per un etimo nuovo: prima quelle con più parole
export async function lingueScelta(lang: Lang): Promise<{ codice: string; nome: string }[]> {
  return query(
    `select g.codice, coalesce(etichetta_in('lingua', g.codice, $1), g.nome) as nome
       from lingua g left join (select lingua, count(*) as n from lessema group by lingua) c on c.lingua = g.codice
      order by coalesce(c.n, 0) desc, 2`, [lang]);
}

// ---- liste di lavoro (prime-100) ----
export interface VoceLista {
  posizione: number; slug: string; lemma: string; gruppo: string; suggerimento: string | null;
  glossa: string | null; stato: string | null; fonti: number; date: number;
}
export interface PostoInLista {
  lista: string; posizione: number; gruppo: string; suggerimento: string | null; totale: number;
  prossima: { slug: string; lemma: string } | null;
}

// le voci di una lista, con lo stato dell'ipotesi accolta, le fonti e le date
export async function listaLavoro(lang: Lang, lista = 'prime-100'): Promise<VoceLista[]> {
  try {
    return await query<VoceLista>(
      `select w.posizione, l.slug, l.lemma, w.gruppo, w.suggerimento,
              coalesce((select g.testo from glossa g where g.lessema_id = l.id and g.lingua = $1 and g.accezione_id is null), l.glossa) as glossa,
              (select h.stato_editoriale::text from ipotesi h where h.esito_id = l.id and h.stato = 'accolta' limit 1) as stato,
              (select count(*)::int from rimando m join ipotesi h on h.id = m.ipotesi_id where h.esito_id = l.id) as fonti,
              (select count(*)::int from attestazione a where a.lessema_id = l.id) as date
         from lista_lavoro w join lessema l on l.id = w.lessema_id
        where w.lista = $2 order by w.posizione`, [lang, lista]);
  } catch {
    return [];          // database senza liste di lavoro (prima dell'aggiornamento)
  }
}

// il posto di una voce nella lista e la prossima da verificare (dopo questa, poi dall'inizio)
export async function postoInLista(lessemaId: number, lista?: string): Promise<PostoInLista | null> {
  try {
    const r = await query<PostoInLista>(
      `select w.lista, w.posizione, w.gruppo, w.suggerimento,
              (select count(*)::int from lista_lavoro t where t.lista = w.lista) as totale,
              (select jsonb_build_object('slug', l2.slug, 'lemma', l2.lemma)
                 from lista_lavoro w2 join lessema l2 on l2.id = w2.lessema_id
                where w2.lista = w.lista and w2.posizione <> w.posizione
                  and not exists (select 1 from ipotesi h where h.esito_id = w2.lessema_id and h.stato = 'accolta'
                                    and h.stato_editoriale = 'verificato')
                order by (w2.posizione < w.posizione), w2.posizione limit 1) as prossima
         from lista_lavoro w where w.lessema_id = $1 and ($2::text is null or w.lista = $2)
        order by (w.lista = 'prime-100') desc, w.lista limit 1`, [lessemaId, lista ?? null]);
    return r[0] ?? null;
  } catch {
    return null;
  }
}
