-- 2 novembre 2026: stime della prima attestazione dai dizionari del Perseus (import/DATAZIONI.md, passo 1).
-- Copiato da db/05_import_wiktionary.sql. Ripetibile senza danni.

-- ===== Stime della prima attestazione dai dizionari del Perseus (novembre 2026, import/DATAZIONI.md) =====
-- Per ogni voce del Lewis & Short e dell'LSJ, l'autore datato più antico tra quelli citati (datatore_dizionari.py),
-- con la datazione di Wikidata. Entrano come attestazioni con stima = true: «almeno dal 184 a.C. — Plauto, secondo il
-- Lewis & Short».
create unlogged table if not exists stg_autore (lingua text, ident text, nome text, anno_da int, anno_a int, precisione text, wikidata text);
create unlogged table if not exists stg_stima (
  chiave text, lingua text, lemma text, anno int, precisione text, autore text, opera text, fonte text, confidenza int);

-- Le stime vanno solo dove la voce è certa: la voce del dizionario stessa (id_esterno), oppure un lemma che ha una sola
-- voce nel dizionario e una sola nella sua lingua. Gli omografi ambigui (caro, tre voci nel Lewis & Short) restano senza.
create or replace function importa_stime() returns jsonb
language plpgsql as $$
declare
  r jsonb := '{}';
  n int;
begin
  if not exists (select 1 from stg_stima) then
    return jsonb_build_object('saltato', 'tabella di appoggio vuota');
  end if;
  perform set_config('app.import', 'on', true);

  insert into autore (lingua, sigla, nome, anno_da, anno_a, precisione, wikidata, fonte)
  select lingua, ident, nome, anno_da, anno_a, precisione::precisione_data, wikidata, 'Wikidata'
    from stg_autore where exists (select 1 from lingua g where g.codice = stg_autore.lingua)
  on conflict (lingua, sigla) do update
     set nome = excluded.nome, anno_da = excluded.anno_da, anno_a = excluded.anno_a, precisione = excluded.precisione,
         wikidata = excluded.wikidata
   where (autore.nome, autore.anno_da, autore.anno_a, autore.precisione, autore.wikidata)
         is distinct from (excluded.nome, excluded.anno_da, excluded.anno_a, excluded.precisione, excluded.wikidata)
     and autore.fonte = 'Wikidata';
  get diagnostics n = row_count;
  r := r || jsonb_build_object('autori', n);

  create temp table st_nuove on commit drop as
  with per_lemma as (select lingua, lemma, count(*) as n from stg_stima group by 1, 2),
       bersaglio as (
    select s.*, coalesce(
             (select l.id from lessema l where l.id_esterno = s.chiave),
             (select min(l.id) from lessema l, per_lemma p
               where p.lingua = s.lingua and p.lemma = s.lemma and p.n = 1
                 and l.lingua = s.lingua and l.lemma = s.lemma and not l.ricostruito
              having count(*) = 1)) as lessema_id
      from stg_stima s)
  select lessema_id, 'stima:' || chiave as id_esterno, autore, anno, precisione::precisione_data as precisione, fonte,
         'https://scaife.perseus.org/library/urn:cts:' || case when lingua = 'la' then 'latinLit' else 'greekLit' end
           || ':' || opera || '/' as url,
         least(greatest(confidenza, 1), 4) as confidenza
    from bersaglio where lessema_id is not null;
  create index on st_nuove (id_esterno);

  -- le stime importate che non valgono più (o sono cambiate) si tolgono; le uguali restano dove sono
  delete from attestazione a
   where a.provenienza = 'perseus' and a.stima and a.stato_editoriale = 'importato' and a.id_esterno like 'stima:%'
     and not exists (select 1 from st_nuove x where x.id_esterno = a.id_esterno and x.lessema_id = a.lessema_id
                       and x.autore = a.testo and x.anno = a.anno_da and x.precisione = a.precisione
                       and x.fonte = a.banca_dati and x.url is not distinct from a.url and x.confidenza = a.confidenza);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('stime_tolte', n);
  insert into attestazione (lessema_id, testo, tipo, anno_da, precisione, banca_dati, url, stima, confidenza,
                            provenienza, stato_editoriale, id_esterno)
  select x.lessema_id, x.autore, 'lessicografica', x.anno, x.precisione, x.fonte, x.url, true, x.confidenza,
         'perseus', 'importato', x.id_esterno
    from st_nuove x
   where not exists (select 1 from attestazione a where a.id_esterno = x.id_esterno and a.lessema_id = x.lessema_id);
  get diagnostics n = row_count;
  r := r || jsonb_build_object('stime_nuove', n,
    'stime', (select count(*) from attestazione where provenienza = 'perseus' and stima));
  return r;
end $$;
comment on function importa_stime() is 'Stime della prima attestazione dai dizionari del Perseus: l''autore datato più antico citato nella voce, solo dove la voce è certa.';
